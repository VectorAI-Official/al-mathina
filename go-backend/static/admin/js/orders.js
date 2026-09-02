/**
 * AL-Madhina Admin - Orders Management
 * Handles order listing, details view, status updates, and invoice printing
 */

// ============ WEIGHT-BASED PRICE CONVERSION UTILITIES ============

/**
 * Parses a weight string like "500g", "1.5kg", "500ml", "1L"
 * Returns {value: number, subUnit: string} or {value: 0, subUnit: ''}
 */
function parseWeight(weightStr) {
    if (!weightStr || typeof weightStr !== 'string') return { value: 0, subUnit: '' };
    weightStr = weightStr.trim().toLowerCase();
    if (!weightStr) return { value: 0, subUnit: '' };

    const subUnits = ['kg', 'g', 'ml', 'l', 'ltr', 'liter', 'liters'];
    for (const su of subUnits) {
        if (weightStr.endsWith(su)) {
            const numStr = weightStr.substring(0, weightStr.length - su.length).trim();
            if (!numStr) return { value: 0, subUnit: '' };
            const val = parseFloat(numStr);
            if (isNaN(val)) return { value: 0, subUnit: '' };
            return { value: val, subUnit: su };
        }
    }
    return { value: 0, subUnit: '' };
}

/**
 * Normalizes variant sub-units to canonical base forms.
 */
function _normalizeSubUnit(sub) {
    if (['l', 'ltr', 'liter', 'liters'].includes(sub)) return 'l';
    return sub;
}

/**
 * Normalizes the product's unit field to canonical base forms.
 */
function _normalizeBaseUnit(unit) {
    if (!unit || typeof unit !== 'string') return '';
    const u = unit.trim().toLowerCase();
    if (u === 'kg') return 'kg';
    if (u === 'g') return 'g';
    if (['liters', 'liter', 'ltr', 'l'].includes(u)) return 'l';
    if (u === 'ml') return 'ml';
    if (['pieces', 'piece', 'pcs', 'pc', 'units', 'unit', 'nos'].includes(u)) return 'pieces';
    return u;
}

/**
 * Computes the effective price for a product variant based on its
 * per-unit price and the actual weight/size.
 *
 * Examples:
 *   calculateEffectivePrice(120, "500g", "kg")    → 60.00
 *   calculateEffectivePrice(120, "1kg", "kg")     → 120.00
 *   calculateEffectivePrice(40, "500ml", "liters") → 20.00
 *   calculateEffectivePrice(10, "", "pieces")       → 10.00
 */
function calculateEffectivePrice(pricePerUnit, weight, unit) {
    if (!pricePerUnit || pricePerUnit <= 0) return pricePerUnit || 0;

    const baseUnit = _normalizeBaseUnit(unit);
    if (baseUnit === 'pieces' || baseUnit === '') return pricePerUnit;

    const parsed = parseWeight(weight);
    if (parsed.value <= 0 || !parsed.subUnit) return pricePerUnit;

    const normSub = _normalizeSubUnit(parsed.subUnit);
    let factor;

    if (baseUnit === 'kg') {
        if (normSub === 'g') factor = parsed.value / 1000.0;
        else if (normSub === 'kg') factor = parsed.value;
        else return pricePerUnit;
    } else if (baseUnit === 'l') {
        if (normSub === 'ml') factor = parsed.value / 1000.0;
        else if (normSub === 'l') factor = parsed.value;
        else return pricePerUnit;
    } else {
        return pricePerUnit;
    }

    return Math.round(pricePerUnit * factor * 100) / 100;
}

// Global state
let allOrders = [];
let filteredOrders = []; // Currently filtered/displayed orders
let currentOrder = null;
let originalOrderItemsSnapshot = [];
let selectedOrderIds = new Set(); // Track selected order IDs for bulk actions

// Return Items editing state (namespaced to keep separate from Order Items)
let originalReturnItemsSnapshot = [];
let returnIsEditMode = false;
let returnSectionExpanded = false;
let selectedDateFilter = {
    type: 'all', // 'all', 'single', 'range'
    singleDate: null,
    startDate: null,
    endDate: null
};

// Lazy loading state for orders
let displayedOrdersCount = 0;
const ORDERS_PER_PAGE = 100;
const ORDERS_LOAD_THRESHOLD = 80; // Load more when scrolling to 80th item

// Header scroll behavior state
let lastScrollTop = 0;
let scrollTimeout;

// Initialize orders management
document.addEventListener('DOMContentLoaded', function () {
    console.log('🚀 Orders page initialized');

    // Check if we're on the orders page
    if (document.getElementById('ordersContainer')) {
        loadOrders();
        setupEventListeners();
        setupHeaderScrollBehavior();
    }
});

// Setup header hide/show on scroll
function setupHeaderScrollBehavior() {
    const header = document.querySelector('.orders-header');
    if (!header) return;

    window.addEventListener('scroll', () => {
        clearTimeout(scrollTimeout);
        scrollTimeout = setTimeout(() => {
            const currentScroll = window.pageYOffset || document.documentElement.scrollTop;

            // Ignore if at top
            if (currentScroll <= 0) {
                header.classList.remove('header-hidden');
                return;
            }

            // Scrolling down - hide header
            if (currentScroll > lastScrollTop && currentScroll > 100) {
                header.classList.add('header-hidden');
            }
            // Scrolling up - show header
            else if (currentScroll < lastScrollTop) {
                header.classList.remove('header-hidden');
            }

            lastScrollTop = currentScroll <= 0 ? 0 : currentScroll;
        }, 50);
    }, { passive: true });
}

// Setup event listeners
function setupEventListeners() {
    console.log('🎯 Setting up event listeners');

    // Search input - try both IDs for compatibility
    const searchInput = document.getElementById('searchInput') || document.getElementById('orderSearch');
    if (searchInput) {
        searchInput.addEventListener('input', filterOrders);
        searchInput.addEventListener('keyup', filterOrders);
        console.log('   ✅ Search listeners attached');
    } else {
        console.warn('   ⚠️  Search input not found');
    }

    // Status filter
    const statusFilter = document.getElementById('statusFilter');
    if (statusFilter) {
        statusFilter.addEventListener('change', filterOrders);
        console.log('   ✅ Status filter listener attached');
    } else {
        console.warn('   ⚠️  Status filter not found');
    }

    // Keyboard shortcuts
    document.addEventListener('keydown', function (e) {
        if (e.key === 'Escape') {
            const revenueModal = document.getElementById('revenueModal');
            const orderModal = document.getElementById('orderDetailsModal');

            if (revenueModal && revenueModal.style.display !== 'none') {
                closeRevenueModal();
            } else if (orderModal && orderModal.style.display !== 'none') {
                closeOrderDetailsModal();
            }
        }
    });
}

// Load all orders
async function loadOrders() {
    console.log('🔄 Loading orders from /api/admin/orders');
    try {
        showLoading('ordersContainer');

        const response = await fetch('/api/admin/orders');
        console.log(`📡 API Response Status: ${response.status} ${response.statusText}`);

        if (!response.ok) {
            throw new Error(`HTTP ${response.status}: ${response.statusText}`);
        }

        const data = await response.json();
        console.log('📦 Full API Response:', data);
        console.log(`🔢 data.success = ${data.success}`);
        console.log(`📋 data.orders type = ${typeof data.orders}, length = ${data.orders?.length || 'undefined'}`);
        console.log(`✅ Loaded ${data.orders?.length || 0} orders`);

        if (data.success) {
            console.log('✔️ data.success is true, assigning to allOrders');
            allOrders = data.orders;
            filteredOrders = data.orders; // Initialize filtered orders with all orders

            // Check URL parameters for search/filter on page load
            const urlParams = new URLSearchParams(window.location.search);
            const searchParam = urlParams.get('search');
            const statusParam = urlParams.get('status');

            if (searchParam) {
                console.log(`🔍 Auto-searching for: ${searchParam}`);
                const searchInput = document.getElementById('searchInput') || document.getElementById('orderSearch');
                if (searchInput) {
                    searchInput.value = searchParam;
                }
            }

            if (statusParam) {
                console.log(`🔍 Auto-filtering status: ${statusParam}`);
                const statusFilter = document.getElementById('statusFilter');
                if (statusFilter) {
                    statusFilter.value = statusParam;
                }
            }

            // Apply filters if URL parameters exist
            if (searchParam || statusParam) {
                filterOrders();
            } else {
                displayOrders(allOrders);
                updateOrderStats();
            }
        } else {
            showError('ordersContainer', 'Failed to load orders');
        }
    } catch (error) {
        console.error('❌ Error loading orders:', error);
        showError('ordersContainer', 'Error loading orders: ' + error.message);
    }
}

// Display orders in list with lazy loading
function displayOrders(orders, append = false) {
    const container = document.getElementById('ordersContainer');

    if (!container) {
        console.error('❌ ordersContainer element not found!');
        return;
    }

    if (orders.length === 0) {
        container.innerHTML = `
            <div class="empty-state">
                <i class="fas fa-shopping-bag" style="font-size: 64px; color: #ccc;"></i>
                <h3>No Orders Found</h3>
                <p>Orders will appear here once customers place them.</p>
            </div>
        `;
        displayedOrdersCount = 0;
        return;
    }

    try {
        // Reset count if not appending
        if (!append) {
            displayedOrdersCount = 0;
        }

        // Calculate slice range
        const start = displayedOrdersCount;
        const end = Math.min(start + ORDERS_PER_PAGE, orders.length);
        const ordersToShow = orders.slice(start, end);

        const newHTML = ordersToShow.map(order => `
            <div class="order-card" data-order-id="${order.order_id}" data-order-index="${displayedOrdersCount + ordersToShow.indexOf(order)}">
                <div class="order-card-header">
                    ${order.status !== 'delivered' ? `
                    <div class="order-checkbox-container">
                        <input type="checkbox" 
                               class="order-checkbox" 
                               id="checkbox-${order.order_id}"
                               data-order-id="${order.order_id}"
                               onchange="toggleOrderSelection('${order.order_id}', this.checked)"
                               onclick="event.stopPropagation()">
                        <label for="checkbox-${order.order_id}" onclick="event.stopPropagation()"></label>
                    </div>
                    ` : ''}
                    <div class="order-info" onclick="viewOrderDetails('${order.order_id}')">
                        <h3>Order #${order.order_id}</h3>
                        <p class="order-date">
                            <i class="fas fa-calendar"></i>
                            ${formatDateTime(order.created_at)}
                        </p>
                    </div>
                    <span class="status-badge status-${order.status}">${order.status.toUpperCase()}</span>
                </div>
                
                <div class="order-card-body" onclick="viewOrderDetails('${order.order_id}')">
                    <div class="customer-info">
                        <div class="info-row">
                            <i class="fas fa-user"></i>
                            <span>
                                <strong>${order.user_name || 'Unknown Customer'}</strong>
                                ${order.user_store_name ? `<span style="color: #2E7D32; font-weight: 600; margin-left: 8px;">(<i class="fas fa-store" style="margin-right: 4px;"></i>${order.user_store_name})</span>` : ''}
                            </span>
                        </div>
                        <div class="info-row">
                            <i class="fas fa-phone"></i>
                            <span>${order.user_phone}</span>
                        </div>
                    </div>
                    
                    <div class="order-summary">
                        <div class="summary-item">
                            <span class="label">Items:</span>
                            <span class="value">${order.items?.length || 0}</span>
                        </div>
                        <div class="summary-item">
                            <span class="label">Total Amount:</span>
                            <span class="value amount">₹${parseFloat(order.total_amount).toFixed(2)}</span>
                        </div>
                    </div>
                </div>
                
                <div class="order-card-footer">
                    <div class="footer-left">
                        <span class="payment-method">
                            <i class="fas fa-credit-card"></i>
                            ${order.payment_method || 'COD'}
                        </span>
                        <button class="delete-order-btn" onclick="event.stopPropagation(); deleteOrder('${order.order_id}')">
                            <i class="fas fa-trash"></i> Delete
                        </button>
                    </div>
                    <span class="view-link" onclick="viewOrderDetails('${order.order_id}')">
                        View Details <i class="fas fa-chevron-right"></i>
                    </span>
                </div>
            </div>
        `).join('');

        // Append or replace HTML
        if (append) {
            container.insertAdjacentHTML('beforeend', newHTML);
        } else {
            container.innerHTML = newHTML;
        }

        // Update displayed count
        displayedOrdersCount = end;

        // Restore checkbox states
        selectedOrderIds.forEach(orderId => {
            const checkbox = document.getElementById(`checkbox-${orderId}`);
            if (checkbox) checkbox.checked = true;
        });

        // Update bulk action button visibility
        updateBulkActionButton();

        // Setup scroll listener
        setupOrderScrollListener(orders);

        console.log(`✅ Displayed ${displayedOrdersCount}/${orders.length} orders`);
    } catch (displayError) {
        console.error('❌ Error generating order HTML:', displayError);
        container.innerHTML = `
            <div class="error-state">
                <i class="fas fa-exclamation-triangle" style="font-size: 48px; color: #f44336;"></i>
                <h3>Display Error</h3>
                <p>Error rendering orders: ${displayError.message}</p>
            </div>
        `;
    }
}

// Setup scroll listener for lazy loading orders
let orderLoadObserver = null;

function setupOrderScrollListener(orders) {
    const container = document.getElementById('ordersContainer');

    // Disconnect existing observer
    if (orderLoadObserver) {
        orderLoadObserver.disconnect();
    }

    // Store current orders list
    window.currentOrdersList = orders;

    // Check if we've loaded everything
    if (displayedOrdersCount >= orders.length) return;

    // Create sentinel element at the end
    let sentinel = document.getElementById('order-load-sentinel');
    if (!sentinel) {
        sentinel = document.createElement('div');
        sentinel.id = 'order-load-sentinel';
        sentinel.style.height = '1px';
        sentinel.style.visibility = 'hidden';
    }
    container.appendChild(sentinel);

    // Create IntersectionObserver for smooth lazy loading
    orderLoadObserver = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
            if (entry.isIntersecting && displayedOrdersCount < orders.length) {
                displayOrders(orders, true); // Load next batch
            }
        });
    }, {
        root: null,
        rootMargin: '300px', // Start loading 300px before reaching the end
        threshold: 0.1
    });

    orderLoadObserver.observe(sentinel);
}

// View order details
async function viewOrderDetails(orderId) {
    try {
        // Show loading in the modal content
        const modal = document.getElementById('orderDetailsModal');
        const content = document.getElementById('orderDetailsContent');

        if (!content) {
            console.error('orderDetailsContent element not found');
            return;
        }

        content.innerHTML = `
            <div class="modal-body">
                <div class="loading">
                    <div class="spinner"></div>
                    <p>Loading order details...</p>
                </div>
            </div>
        `;
        modal.style.display = 'block';

        const response = await fetch(`/api/admin/orders/${orderId}`);
        const data = await response.json();

        if (data.success) {
            currentOrder = data.order;
            showOrderDetailsModal(data.order);
        } else {
            content.innerHTML = `
                <div class="modal-body">
                    <div class="error-state">
                        <i class="fas fa-exclamation-triangle" style="font-size: 48px; color: #f44336;"></i>
                        <h3>Error</h3>
                        <p>Failed to load order details</p>
                    </div>
                </div>
            `;
        }
    } catch (error) {
        console.error('Error loading order details:', error);
        const content = document.getElementById('orderDetailsContent');
        if (content) {
            content.innerHTML = `
                <div class="modal-body">
                    <div class="error-state">
                        <i class="fas fa-exclamation-triangle" style="font-size: 48px; color: #f44336;"></i>
                        <h3>Error</h3>
                        <p>Error loading order details: ${error.message}</p>
                    </div>
                </div>
            `;
        }
    }
}

// Show order details modal
function showOrderDetailsModal(order) {
    const modal = document.getElementById('orderDetailsModal');
    if (!modal) return;

    // Render content
    renderOrderDetails(order);

    modal.style.display = 'block';
}

// Balance summary labels shown in Tamil on the order details modal and the
// generated invoice PDF. Kept in one place so both renderers stay in sync.
const balanceLabels = {
    heading: 'இருப்பு சுருக்கம்',
    beforeOrder: 'இந்த ஆர்டருக்கு முன் இருப்பு',
    orderAmount: 'இந்த ஆர்டர் தொகை',
    totalOutstanding: 'மொத்த நிலுவை',
};

// Render order details content (extracted for re-use)
function renderOrderDetails(order) {
    const content = document.getElementById('orderDetailsContent');
    if (!content) return;

    content.innerHTML = `
        <div class="modal-body">
            <div class="order-details-header">
                <div>
                    <h2>Order #${order.order_id}</h2>
                    <p class="order-meta">${formatDateTime(order.created_at)}</p>
                </div>
                <span class="status-badge status-${order.status}">${order.status.toUpperCase()}</span>
            </div>
            
            <div class="order-sections">
                <!-- Customer Information -->
                <div class="detail-section">
                    <h3><i class="fas fa-user-circle"></i> Customer Information</h3>
                    <div class="detail-grid">
                        <div class="detail-item">
                            <label>Name:</label>
                            <span>${order.user_name || 'Unknown'}</span>
                        </div>
                        <div class="detail-item">
                            <label>Phone:</label>
                            <span>${order.user_phone}</span>
                        </div>
                        ${order.user_store_name ? `
                            <div class="detail-item full-width">
                                <label>Store Name:</label>
                                <span>${order.user_store_name}</span>
                            </div>
                        ` : ''}
                    </div>
                </div>
                
                <!-- Delivery Address -->
                ${order.user_store_address && (order.user_store_address.street || order.user_store_address.city) ? `
                    <div class="detail-section">
                        <h3><i class="fas fa-map-marker-alt"></i> Delivery Address</h3>
                        <div class="address-text">
                            ${order.user_store_address.street || ''}<br>
                            ${order.user_store_address.city || ''}, ${order.user_store_address.state || ''} - ${order.user_store_address.pincode || ''}
                            ${order.user_store_address.landmark ? `<br>Landmark: ${order.user_store_address.landmark}` : ''}
                        </div>
                    </div>
                ` : order.delivery_address && (order.delivery_address.street || order.delivery_address.city) ? `
                    <div class="detail-section">
                        <h3><i class="fas fa-map-marker-alt"></i> Delivery Address</h3>
                        <div class="address-text">
                            ${order.delivery_address.street || ''}<br>
                            ${order.delivery_address.city || ''}, ${order.delivery_address.state || ''} - ${order.delivery_address.pincode || ''}
                            ${order.delivery_address.landmark ? `<br>Landmark: ${order.delivery_address.landmark}` : ''}
                        </div>
                    </div>
                ` : ''}
                
                <!-- Balance Summary -->
                ${order.is_store_order ? `
                    <div class="detail-section balance-summary">
                        <h3><i class="fas fa-wallet"></i> ${balanceLabels.heading}</h3>
                        <div class="balance-row">
                            <span class="balance-label">${balanceLabels.beforeOrder}</span>
                            <span class="balance-value">₹${formatInvoiceCurrency(order.balance_before)}</span>
                        </div>
                        <div class="balance-row">
                            <span class="balance-label">${balanceLabels.orderAmount}</span>
                            <span class="balance-value">₹${formatInvoiceCurrency(order.order_amount != null ? order.order_amount : order.total_amount)}</span>
                        </div>
                        <div class="balance-row grand">
                            <span class="balance-label">${balanceLabels.totalOutstanding}</span>
                            <span class="balance-value">₹${formatInvoiceCurrency(order.balance_total)}</span>
                        </div>
                    </div>
                ` : ''}
                
                <!-- Order Items -->
                <div class="detail-section">
                    <h3>
                        <i class="fas fa-box-open"></i> Order Items
                        <button class="btn-edit-items" onclick="toggleEditMode()" title="Edit Quantities">
                            <i class="fas fa-edit"></i> Edit
                        </button>
                    </h3>
                    <!-- Add Product Search (hidden by default, shown in edit mode) -->
                    <div id="addProductContainer" style="display: none; margin-bottom: 20px; padding: 15px; background: #f5f5f5; border-radius: 8px;">
                        <h4 style="margin: 0 0 10px 0; color: #1B5E20;"><i class="fas fa-plus-circle"></i> Add Product to Order</h4>
                        <div style="display: flex; gap: 10px; align-items: flex-start;">
                            <div style="flex: 1; position: relative;">
                                <input type="text" id="productSearchInput" placeholder="Search product by name..." 
                                    style="width: 100%; padding: 10px; border: 2px solid #4CAF50; border-radius: 6px; font-size: 14px;"
                                    onkeyup="searchProducts(this.value)">
                                <div id="productSearchResults" style="position: absolute; top: 100%; left: 0; right: 0; background: white; border: 1px solid #ddd; border-radius: 6px; max-height: 300px; overflow-y: auto; z-index: 1000; display: none; box-shadow: 0 4px 12px rgba(0,0,0,0.15);"></div>
                            </div>
                            <button class="btn btn-secondary" onclick="clearProductSearch()" style="padding: 10px 20px;">
                                <i class="fas fa-times"></i> Clear
                            </button>
                        </div>
                    </div>
                    <div class="items-table">
                        <table id="orderItemsTable">
                            <thead>
                                <tr>
                                    <th>Product</th>
                                    <th>Weight</th>
                                    <th>Price</th>
                                    <th>Qty</th>
                                    <th>Total</th>
                                    <th style="display: none;" class="edit-only-column">Action</th>
                                </tr>
                            </thead>
                            <tbody>
                                ${order.items.map((item, index) => `
                                    <tr data-item-index="${index}" data-product-id="${item.product_id || ''}" data-price="${item.price}" data-weight="${item.weight || ''}">
                                        <td><strong>${item.product_name}</strong></td>
                                        <td>${item.weight || '-'}</td>
                                        <td class="price-cell">
                                            <span class="price-display">₹${parseFloat(item.price).toFixed(2)}</span>
                                            <input type="number" class="price-input" value="${item.price}" min="0" step="0.01" style="display: none;" data-original="${item.price}">
                                        </td>
                                        <td class="qty-cell">
                                            <span class="qty-display">×${item.quantity}</span>
                                            <input type="number" class="qty-input" value="${item.quantity}" min="1" style="display: none;" data-original="${item.quantity}">
                                        </td>
                                        <td class="item-total"><strong>₹${(item.price * item.quantity).toFixed(2)}</strong></td>
                                        <td style="display: none;" class="edit-only-column">
                                            <button class="btn-delete-item" onclick="removeOrderItem(this)" style="display: none; background: #f44336; color: white; border: none; padding: 6px 12px; border-radius: 4px; cursor: pointer;" title="Remove item">
                                                <i class="fas fa-trash"></i>
                                            </button>
                                        </td>
                                    </tr>
                                `).join('')}
                            </tbody>
                            <tfoot>
                                <tr>
                                    <td colspan="4" style="text-align: right;"><strong>Grand Total:</strong></td>
                                    <td><strong class="total-amount">₹${parseFloat(order.total_amount).toFixed(2)}</strong></td>
                                    <td style="display: none;" class="edit-only-column"></td>
                                </tr>
                            </tfoot>
                        </table>
                    </div>
                    <div id="saveButtonContainer" style="display: none; margin-top: 15px; text-align: right;">
                        <button class="btn btn-primary" onclick="saveOrderChanges('${order.order_id}')" style="margin-right: 10px;">
                            <i class="fas fa-save"></i> Save Changes
                        </button>
                        <button class="btn btn-secondary" onclick="cancelEditMode()">
                            <i class="fas fa-times"></i> Cancel
                        </button>
                    </div>
                </div>
                
                <!-- Return Items -->
                <div class="detail-section" style="border-left: 4px solid #F57C00;">
                    <h3>
                        <i class="fas fa-undo-alt" style="color: #F57C00;"></i> <span style="color: #E65100;">Return Items</span>
                        ${order.return_items && order.return_items.length > 0 ? `
                            <button class="btn-edit-return-items" onclick="toggleReturnEditMode()" title="Edit Return Quantities"
                                style="background: #F57C00; color: white; border: none; padding: 6px 12px; border-radius: 4px; cursor: pointer; font-size: 13px;">
                                <i class="fas fa-edit"></i> Edit
                            </button>
                        ` : `
                            <button class="btn-add-return-items" onclick="openReturnItemsEditor()" title="Add Return Items"
                                style="background: #F57C00; color: white; border: none; padding: 6px 12px; border-radius: 4px; cursor: pointer; font-size: 13px;">
                                <i class="fas fa-plus-circle"></i> Add Return Items
                            </button>
                        `}
                    </h3>
                    <!-- Add Return Product Search (hidden by default, shown in return edit mode) -->
                    <div id="returnAddProductContainer" style="display: none; margin-bottom: 20px; padding: 15px; background: #FFF8F0; border-radius: 8px; border: 1px solid #F57C00;">
                        <h4 style="margin: 0 0 10px 0; color: #E65100;"><i class="fas fa-plus-circle"></i> Add Product to Return</h4>
                        <div style="display: flex; gap: 10px; align-items: flex-start;">
                            <div style="flex: 1; position: relative;">
                                <input type="text" id="returnProductSearchInput" placeholder="Search product by name..."
                                    style="width: 100%; padding: 10px; border: 2px solid #F57C00; border-radius: 6px; font-size: 14px;"
                                    onkeyup="searchReturnProducts(this.value)">
                                <div id="returnProductSearchResults" style="position: absolute; top: 100%; left: 0; right: 0; background: white; border: 1px solid #ddd; border-radius: 6px; max-height: 300px; overflow-y: auto; z-index: 1000; display: none; box-shadow: 0 4px 12px rgba(0,0,0,0.15);"></div>
                            </div>
                            <button class="btn btn-secondary" onclick="clearReturnProductSearch()" style="padding: 10px 20px;">
                                <i class="fas fa-times"></i> Clear
                            </button>
                        </div>
                    </div>
                    <div id="returnItemsTableContainer" style="${order.return_items && order.return_items.length > 0 ? '' : 'display: none;'}">
                        <div class="items-table">
                            <table id="returnItemsTable">
                                <thead>
                                    <tr>
                                        <th>Product</th>
                                        <th>Weight</th>
                                        <th>Price</th>
                                        <th>Qty</th>
                                        <th>Total</th>
                                        <th style="display: none;" class="return-edit-only-column">Action</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    ${(order.return_items || []).map((item, index) => `
                                        <tr data-item-index="${index}" data-product-id="${item.item_id || ''}" data-price="${item.price}" data-weight="${item.weight || ''}" data-unit="${item.unit || ''}">
                                            <td><strong>${item.product_name}</strong></td>
                                            <td>${item.weight || '-'}</td>
                                            <td class="return-price-cell">
                                                <span class="return-price-display">₹${parseFloat(item.price).toFixed(2)}</span>
                                                <input type="number" class="return-price-input" value="${item.price}" min="0" step="0.01" style="display: none;" data-original="${item.price}">
                                            </td>
                                            <td class="return-qty-cell">
                                                <span class="return-qty-display">×${item.quantity}</span>
                                                <input type="number" class="return-qty-input" value="${item.quantity}" min="1" style="display: none;" data-original="${item.quantity}">
                                            </td>
                                            <td class="return-item-total"><strong>₹${(item.price * item.quantity).toFixed(2)}</strong></td>
                                            <td style="display: none;" class="return-edit-only-column">
                                                <button class="btn-delete-return-item" onclick="removeReturnItem(this)" style="display: none; background: #f44336; color: white; border: none; padding: 6px 12px; border-radius: 4px; cursor: pointer;" title="Remove item">
                                                    <i class="fas fa-trash"></i>
                                                </button>
                                            </td>
                                        </tr>
                                    `).join('')}
                                </tbody>
                                <tfoot>
                                    <tr>
                                        <td colspan="4" style="text-align: right;"><strong style="color: #E65100;">Return Items Total:</strong></td>
                                        <td><strong class="return-total-amount" style="color: #E65100;">₹${parseFloat(order.return_total || 0).toFixed(2)}</strong></td>
                                        <td style="display: none;" class="return-edit-only-column"></td>
                                    </tr>
                                </tfoot>
                            </table>
                        </div>
                    </div>
                    <div id="returnSaveButtonContainer" style="display: none; margin-top: 15px; text-align: right;">
                        <button class="btn btn-primary" onclick="saveReturnItemsChanges('${order.order_id}')" style="margin-right: 10px; background: #F57C00; border-color: #F57C00;">
                            <i class="fas fa-save"></i> Save Return Items
                        </button>
                        <button class="btn btn-secondary" onclick="cancelReturnEditMode()">
                            <i class="fas fa-times"></i> Cancel
                        </button>
                    </div>
                </div>
                
                <!-- Payment Information -->
                <div class="detail-section">
                    <h3><i class="fas fa-credit-card"></i> Payment Information</h3>
                    <div class="detail-grid">
                        <div class="detail-item">
                            <label>Payment Method:</label>
                            <span>${order.payment_method || 'Cash on Delivery'}</span>
                        </div>
                        <div class="detail-item">
                            <label>Total Amount:</label>
                            <span class="amount">₹${parseFloat(order.total_amount).toFixed(2)}</span>
                        </div>
                    </div>
                </div>
            </div>
        </div>
        
        <!-- Action Buttons -->
        <div class="order-actions" id="orderActionButtons">
            ${order.status === 'pending' ? `
                <button class="btn btn-success action-btn" onclick="updateOrderStatus('${order.order_id}', 'delivered')">
                    <i class="fas fa-check-circle"></i> Mark as Delivered
                </button>
                <button class="btn btn-danger action-btn" onclick="updateOrderStatus('${order.order_id}', 'cancelled')">
                    <i class="fas fa-times-circle"></i> Cancel Order
                </button>
            ` : `
                <div class="status-info">
                    Order is ${order.status}
                </div>
            `}
            <button class="btn btn-success action-btn" onclick="shareInvoiceWhatsApp('${order.order_id}')" style="margin-right: 10px;">
                <i class="fab fa-whatsapp"></i> Share on WhatsApp
            </button>
            <button class="btn btn-primary action-btn" onclick="printInvoice('${order.order_id}')">
                <i class="fas fa-print"></i> Print Invoice
            </button>
        </div>
    `;
}

// Update order status
async function updateOrderStatus(orderId, newStatus) {
    if (!confirm(`Are you sure you want to mark this order as ${newStatus}?`)) {
        return;
    }

    try {
        const response = await fetch(`/api/admin/orders/${orderId}/status`, {
            method: 'PUT',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({ status: newStatus })
        });

        const data = await response.json();

        if (data.success) {
            alert(`Order ${newStatus} successfully!`);
            closeOrderDetailsModal();
            loadOrders(); // Reload orders list
        } else {
            alert('Failed to update order status');
        }
    } catch (error) {
        console.error('Error updating order status:', error);
        alert('Error updating order status: ' + error.message);
    }
}

// Print invoice - generates a clean PDF via html2canvas + jsPDF (no browser print URL header)
async function printInvoice(orderId) {
    const order = currentOrder;
    if (!order) return;

    // Hide the modal while the PDF is generated
    const modal = document.getElementById('orderDetailsModal');
    const modalWasVisible = modal && modal.style.display !== 'none';
    if (modalWasVisible) {
        modal.style.display = 'none';
    }

    try {
        const pdf = await generateInvoicePdf(order);

        // Auto-print the clean PDF in a new tab (no URL header/footer)
        pdf.autoPrint();
        const printWindow = window.open(pdf.output('bloburl'), '_blank');
        if (!printWindow) {
            // Popup blocked - fall back to downloading the PDF
            pdf.save(`Invoice_${order.order_id}.pdf`);
            showToast('Print window was blocked - PDF downloaded instead', 'warning');
        }
    } catch (error) {
        console.error('❌ Print PDF generation error:', error);
        showToast('Failed to generate invoice PDF', 'error');
    } finally {
        // Restore modal visibility after a short delay
        if (modalWasVisible && modal) {
            setTimeout(() => {
                modal.style.display = 'block';
            }, 500);
        }
    }
}

// Generate a clean multi-page invoice PDF using html2canvas + jsPDF.
// Avoids the browser's native print header/footer (which shows the page URL).
// Returns a Promise resolving to the jsPDF instance.
async function generateInvoicePdf(order) {
    // Generate invoice HTML - shareMode sizing (A4 width) for canvas capture
    const invoiceHTML = generateInvoiceHTML(order, { shareMode: true, printMode: false });

    // Create hidden iframe - SAME APPROACH AS PRINT/WHATSAPP SHARE
    const iframe = document.createElement('iframe');
    iframe.style.position = 'absolute';
    iframe.style.left = '-9999px';
    iframe.style.top = '-9999px';
    iframe.style.width = '210mm'; // A4 width
    iframe.style.height = '297mm'; // A4 height
    iframe.style.border = 'none';
    iframe.style.visibility = 'hidden';
    document.body.appendChild(iframe);

    const iframeDoc = iframe.contentWindow.document;
    iframeDoc.open();
    iframeDoc.write(invoiceHTML);
    iframeDoc.close();

    // Wait for content to fully render, including the Noto Sans Tamil webfont.
    // Awaiting document.fonts ensures html2canvas renders the balance box in the
    // Tamil font instead of falling back to Arial. html2canvas draws in the PARENT
    // window, so we must also await the parent document's fonts (not just the iframe's).
    try {
        if (iframe.contentWindow.document.fonts) {
            await iframe.contentWindow.document.fonts.load('16px "InvoiceTamil"');
            await iframe.contentWindow.document.fonts.load('700 16px "InvoiceTamil"');
            await iframe.contentWindow.document.fonts.ready;
        }
    } catch (e) {
        // Fonts API unavailable - fall through to the render delay below.
    }
    try {
        if (document.fonts) {
            await document.fonts.load('16px "InvoiceTamil"');
            await document.fonts.load('700 16px "InvoiceTamil"');
            await document.fonts.ready;
        }
    } catch (e) {
        // Fonts API unavailable - fall through to the render delay below.
    }
    await new Promise(resolve => setTimeout(resolve, 500));

    // Get the invoice container from iframe
    const invoiceElement = iframe.contentWindow.document.querySelector('.invoice-container');
    if (!invoiceElement) {
        document.body.removeChild(iframe);
        throw new Error('Invoice element not found');
    }

    console.log('📸 Capturing invoice as image...');

    // Capture with html2canvas
    const canvas = await html2canvas(invoiceElement, {
        scale: 2, // High quality
        useCORS: true,
        allowTaint: false,
        backgroundColor: '#ffffff',
        logging: false,
        windowWidth: iframe.contentWindow.document.documentElement.scrollWidth,
        windowHeight: iframe.contentWindow.document.documentElement.scrollHeight,
        foreignObjectRendering: false,
        imageTimeout: 0
    });

    // Clean up iframe
    document.body.removeChild(iframe);

    console.log('📄 Converting to PDF...');

    // Create PDF - Simple approach matching print quality
    const { jsPDF } = window.jspdf;
    const pdf = new jsPDF({
        orientation: 'portrait',
        unit: 'mm',
        format: 'a4',
        compress: true
    });

    // Get PDF dimensions
    const pdfWidth = pdf.internal.pageSize.getWidth();
    const pdfHeight = pdf.internal.pageSize.getHeight();

    // Define page margins - First page minimal, subsequent pages with safety buffers
    const topMargin = 0; // No top margin on first page
    const bottomMarginFirstPage = 10; // 10mm bottom margin on first page only (minimal)
    const bottomMargin = 20; // 20mm bottom margin on subsequent pages (increased buffer)
    const topMarginSubsequent = 25; // 25mm top margin on pages 2+ (increased buffer)
    const safetyBuffer = 5; // 5mm extra safety buffer on subsequent pages to avoid row splits

    // Calculate usable heights - First page gets more space, subsequent pages more conservative
    const firstPageUsableHeight = pdfHeight - bottomMarginFirstPage; // First page with minimal bottom margin
    const subsequentPageUsableHeight = pdfHeight - topMarginSubsequent - bottomMargin - safetyBuffer; // Pages 2+ with buffers

    // Calculate scaled image dimensions
    const imgWidth = pdfWidth;
    const imgHeight = (canvas.height * pdfWidth) / canvas.width;

    // Convert canvas to high-quality image
    const imgData = canvas.toDataURL('image/jpeg', 0.95);

    console.log(`📐 PDF Dimensions: ${pdfWidth}mm x ${pdfHeight}mm`);
    console.log(`📐 Image Height: ${imgHeight}mm`);
    console.log(`📐 First Page Usable: ${firstPageUsableHeight}mm`);
    console.log(`📐 Subsequent Usable: ${subsequentPageUsableHeight}mm`);

    // Add image to PDF with intelligent pagination
    if (imgHeight <= firstPageUsableHeight) {
        // Single page - fits perfectly
        pdf.addImage(imgData, 'JPEG', 0, topMargin, imgWidth, imgHeight);
        console.log('📄 Single page layout');
    } else {
        // Multi-page pagination with proper breaks
        let remainingHeight = imgHeight;
        let sourceY = 0; // Y position in source image (in mm)
        let pageNumber = 1;

        // First page
        const firstPageHeight = Math.min(firstPageUsableHeight, remainingHeight);

        // Calculate source dimensions in canvas pixels for clipping
        const canvasHeight = canvas.height;
        const canvasWidth = canvas.width;
        const pixelsPerMm = canvasHeight / imgHeight; // Conversion factor

        // First page: clip from top of canvas
        const firstPageCanvasHeight = firstPageHeight * pixelsPerMm;

        // Create canvas for first page
        const page1Canvas = document.createElement('canvas');
        page1Canvas.width = canvasWidth;
        page1Canvas.height = firstPageCanvasHeight;
        const page1Ctx = page1Canvas.getContext('2d');

        page1Ctx.drawImage(
            canvas,
            0, 0, canvasWidth, firstPageCanvasHeight, // Source clip
            0, 0, canvasWidth, firstPageCanvasHeight  // Destination
        );

        const page1Data = page1Canvas.toDataURL('image/jpeg', 0.95);
        pdf.addImage(page1Data, 'JPEG', 0, topMargin, imgWidth, firstPageHeight);

        sourceY += firstPageHeight;
        remainingHeight -= firstPageHeight;

        console.log(`📄 Page 1: ${firstPageHeight}mm (source 0 → ${firstPageHeight}mm)`);

        // Subsequent pages
        while (remainingHeight > 0) {
            pdf.addPage();
            pageNumber++;

            const pageHeight = Math.min(subsequentPageUsableHeight, remainingHeight);
            const pageCanvasHeight = pageHeight * pixelsPerMm;
            const sourceCanvasY = sourceY * pixelsPerMm;

            // Create canvas for this page
            const pageCanvas = document.createElement('canvas');
            pageCanvas.width = canvasWidth;
            pageCanvas.height = pageCanvasHeight;
            const pageCtx = pageCanvas.getContext('2d');

            pageCtx.drawImage(
                canvas,
                0, sourceCanvasY, canvasWidth, pageCanvasHeight, // Source clip
                0, 0, canvasWidth, pageCanvasHeight              // Destination
            );

            const pageData = pageCanvas.toDataURL('image/jpeg', 0.95);
            pdf.addImage(pageData, 'JPEG', 0, topMarginSubsequent, imgWidth, pageHeight);

            console.log(`📄 Page ${pageNumber}: ${pageHeight}mm (source ${sourceY}mm → ${sourceY + pageHeight}mm)`);

            sourceY += pageHeight;
            remainingHeight -= pageHeight;
        }

        console.log(`✅ Generated ${pageNumber} pages with intelligent pagination`);
    }

    return pdf;
}

// Share invoice on WhatsApp (generates PDF) - Uses same logic as Print Invoice
async function shareInvoiceWhatsApp(orderId) {
    const order = currentOrder;
    if (!order) return;

    try {
        console.log('📄 Generating PDF invoice for WhatsApp share...');

        const pdf = await generateInvoicePdf(order);

        // Generate PDF file
        const pdfBlob = pdf.output('blob');
        const pdfFile = new File([pdfBlob], `Invoice_${order.order_id}.pdf`, { type: 'application/pdf' });

        console.log('✅ PDF generated:', pdfFile.size, 'bytes');

        // Try native share API (works on mobile)
        if (navigator.share && navigator.canShare && navigator.canShare({ files: [pdfFile] })) {
            try {
                await navigator.share({
                    title: `Invoice #${order.order_id}`,
                    text: `Order #${order.order_id} - ${order.user_name || 'Customer'} - ₹${parseFloat(order.total_amount).toFixed(2)}`,
                    files: [pdfFile]
                });
                console.log('✅ Shared successfully');
                return;
            } catch (err) {
                if (err.name === 'AbortError') return;
                console.warn('Share failed:', err);
            }
        }

        // Fallback: Download PDF
        const link = document.createElement('a');
        link.href = URL.createObjectURL(pdfBlob);
        link.download = `Invoice_${order.order_id}.pdf`;
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);
        URL.revokeObjectURL(link.href);

        showToast('Invoice downloaded! Share via WhatsApp', 'success');
    } catch (error) {
        console.error('❌ PDF generation error:', error);
        showToast('Failed to generate PDF', 'error');
    }
}

function shareInvoiceImageFallbackFromCanvas(orderId) {
    const order = currentOrder;
    if (!order) return;
    const invoiceHTML = generateInvoiceHTML(order, { shareMode: true });
    const w = window.open('', '_blank', 'width=800,height=1000');
    w.document.write(invoiceHTML);
    w.document.close();
    setTimeout(async () => {
        // Wait for the Noto Sans Tamil webfont so html2canvas renders it correctly.
        try {
            if (w.document.fonts) {
                await w.document.fonts.load('16px "InvoiceTamil"');
                await w.document.fonts.load('700 16px "InvoiceTamil"');
                await w.document.fonts.ready;
            }
        } catch (e) {
            // Fonts API unavailable - fall through.
        }
        try {
            if (document.fonts) {
                await document.fonts.load('16px "InvoiceTamil"');
                await document.fonts.load('700 16px "InvoiceTamil"');
                await document.fonts.ready;
            }
        } catch (e) {
            // Fonts API unavailable - fall through.
        }
        const canvas = await html2canvas(w.document.body, { scale: 2 });
        w.close();
        canvas.toBlob(blob => {
            const file = new File([blob], `invoice_${order.order_id}.png`, { type: 'image/png' });
            shareInvoiceImageFallback(file, `Invoice - Order #${order.order_id}`, order);
        });
    }, 800);
}

// Note: generateInvoiceHTML(order) is defined later in this file.
// Calls that pass an extra opts parameter will be ignored by that function.

// Toggle edit mode for order quantities
let isEditMode = false;

function toggleEditMode() {
    isEditMode = true;
    originalOrderItemsSnapshot = getOrderItemsFromTable();

    // Show quantity inputs
    document.querySelectorAll('.qty-display').forEach(el => el.style.display = 'none');
    document.querySelectorAll('.qty-input').forEach(el => {
        el.style.display = 'inline';
        el.style.width = '60px';
        el.style.padding = '4px';
        el.style.textAlign = 'center';
        el.style.border = '2px solid #4CAF50';
    });

    // Show price inputs
    document.querySelectorAll('.price-display').forEach(el => el.style.display = 'none');
    document.querySelectorAll('.price-input').forEach(el => {
        el.style.display = 'inline';
        el.style.width = '80px';
        el.style.padding = '4px';
        el.style.textAlign = 'center';
        el.style.border = '2px solid #4CAF50';
    });

    // Show add product container
    const addProductContainer = document.getElementById('addProductContainer');
    if (addProductContainer) addProductContainer.style.display = 'block';

    // Show delete buttons and action column
    document.querySelectorAll('.edit-only-column').forEach(el => el.style.display = 'table-cell');
    document.querySelectorAll('.btn-delete-item').forEach(btn => btn.style.display = 'inline-block');

    // Add event listeners
    document.querySelectorAll('.qty-input').forEach(input => input.addEventListener('input', updateItemTotal));
    document.querySelectorAll('.price-input').forEach(input => input.addEventListener('input', updateItemTotal));

    const saveContainer = document.getElementById('saveButtonContainer');
    if (saveContainer) saveContainer.style.display = 'block';
    document.querySelectorAll('.action-btn').forEach(btn => { btn.disabled = true; btn.style.opacity = '0.5'; btn.style.cursor = 'not-allowed'; });
    const editBtn = document.querySelector('.btn-edit-items');
    if (editBtn) editBtn.style.display = 'none';
}

function cancelEditMode() {
    isEditMode = false;

    // Reset quantity inputs
    document.querySelectorAll('.qty-input').forEach(input => { input.value = input.dataset.original; input.style.display = 'none'; });
    document.querySelectorAll('.qty-display').forEach(el => el.style.display = 'inline');

    // Reset price inputs
    document.querySelectorAll('.price-input').forEach(input => { input.value = input.dataset.original; input.style.display = 'none'; });
    document.querySelectorAll('.price-display').forEach(el => el.style.display = 'inline');

    // Hide add product container
    const addProductContainer = document.getElementById('addProductContainer');
    if (addProductContainer) addProductContainer.style.display = 'none';
    clearProductSearch();

    // Hide delete buttons and action column
    document.querySelectorAll('.edit-only-column').forEach(el => el.style.display = 'none');
    document.querySelectorAll('.btn-delete-item').forEach(btn => btn.style.display = 'none');

    const saveContainer = document.getElementById('saveButtonContainer');
    if (saveContainer) saveContainer.style.display = 'none';
    document.querySelectorAll('.action-btn').forEach(btn => { btn.disabled = false; btn.style.opacity = '1'; btn.style.cursor = 'pointer'; });
    const editBtn = document.querySelector('.btn-edit-items');
    if (editBtn) editBtn.style.display = 'inline-block';
    recalculateGrandTotal();
}

function updateItemTotal(event) {
    const input = event.target;
    const row = input.closest('tr');

    // Get current price (from input if in edit mode, otherwise from data attribute)
    const priceInput = row.querySelector('.price-input');
    const price = priceInput ? parseFloat(priceInput.value) || 0 : parseFloat(row.dataset.price);

    // Get current quantity
    const qtyInput = row.querySelector('.qty-input');
    const quantity = parseInt(qtyInput.value) || 0;

    // Calculate and update item total
    const itemTotal = price * quantity;
    const totalCell = row.querySelector('.item-total strong');
    if (totalCell) totalCell.textContent = `₹${itemTotal.toFixed(2)}`;

    recalculateGrandTotal();
}

function recalculateGrandTotal() {
    let grandTotal = 0;
    document.querySelectorAll('#orderItemsTable tbody tr').forEach(row => {
        // Get price (from input if exists, otherwise from data attribute)
        const priceInput = row.querySelector('.price-input');
        const price = priceInput ? (parseFloat(priceInput.value) || parseFloat(priceInput.dataset.original)) : parseFloat(row.dataset.price);

        // Get quantity
        const qtyInput = row.querySelector('.qty-input');
        const quantity = parseInt(qtyInput?.value) || parseInt(qtyInput?.dataset.original) || 0;

        grandTotal += price * quantity;
    });
    const totalEl = document.querySelector('.total-amount');
    if (totalEl) totalEl.textContent = `₹${grandTotal.toFixed(2)}`;
}

function getOrderItemsFromTable() {
    return Array.from(document.querySelectorAll('#orderItemsTable tbody tr')).map(row => {
        const qtyInput = row.querySelector('.qty-input');
        const priceInput = row.querySelector('.price-input');

        return {
            item_id: (row.dataset.productId || '').trim(),
            product_name: (row.querySelector('td:first-child strong')?.textContent || '').trim(),
            weight: (row.querySelector('td:nth-child(2)')?.textContent || '').trim(),
            price: parseFloat(priceInput?.value) || 0,
            quantity: parseInt(qtyInput?.value) || 0,
            unit: (row.dataset.unit || '').trim()
        };
    });
}

function serializeOrderItemsForComparison(items) {
    const normalized = items.map(item => ({
        item_id: (item.item_id || '').trim(),
        product_name: (item.product_name || '').trim(),
        weight: (item.weight || '').trim(),
        price: Number(item.price || 0),
        quantity: Number(item.quantity || 0)
    }));

    normalized.sort((a, b) => {
        const keyA = `${a.item_id}||${a.product_name}||${a.weight}`;
        const keyB = `${b.item_id}||${b.product_name}||${b.weight}`;
        if (keyA < keyB) return -1;
        if (keyA > keyB) return 1;
        if (a.price !== b.price) return a.price - b.price;
        return a.quantity - b.quantity;
    });

    return JSON.stringify(normalized);
}
async function saveOrderChanges(orderId) {
    if (!confirm('Are you sure you want to save these changes? This will update the order in the database.')) {
        return;
    }

    const updatedItems = getOrderItemsFromTable();
    const hasChanges =
        serializeOrderItemsForComparison(originalOrderItemsSnapshot) !==
        serializeOrderItemsForComparison(updatedItems);

    if (!hasChanges) {
        alert('No changes were made. Add or remove products, or change quantities.');
        cancelEditMode();
        return;
    }

    // Calculate new total
    const newTotal = updatedItems.reduce((sum, item) => sum + (item.price * item.quantity), 0);

    try {
        const response = await fetch(`/api/admin/orders/${orderId}/update-items`, {
            method: 'PUT',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                items: updatedItems,
                total_amount: newTotal
            })
        });

        const data = await response.json();

        if (response.ok) {
            alert('Order updated successfully!');

            // Update current order data with response from server
            currentOrder.items = data.items || updatedItems;
            currentOrder.total_amount = data.total_amount || newTotal;
            currentOrder.grand_total = data.grand_total || newTotal;

            // Re-render the order items table with new data
            renderOrderDetails(currentOrder);

            // Exit edit mode
            cancelEditMode();

            // Refresh main order list in background
            loadOrders();
        } else {
            throw new Error(data.error || 'Failed to update order');
        }
    } catch (error) {
        console.error('Error updating order:', error);
        alert('Error updating order: ' + error.message);
    }
}

// Generate invoice HTML (reusable function)
function generateInvoiceHTML(order, opts = {}) {
    const { printMode = false, shareMode = false } = opts || {};
    // Standard A4-like dimensions for consistent PDF appearance
    // Use 794px (A4 width at 96dpi) for share mode to match canvas container
    const pageWidth = shareMode ? 794 : 210;
    const pagePadding = shareMode ? 40 : 20;

    return `
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=794, initial-scale=1.0, maximum-scale=1.0, user-scalable=no" />
  <title>Invoice - Order #${order.order_id}</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Noto+Sans+Tamil:wght@400;700&display=swap" rel="stylesheet">
  <style>
@font-face { font-family: "InvoiceTamil"; font-style: normal; font-weight: 400; src: url(data:font/woff2;base64,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) format("woff2"); }
    @font-face { font-family: "InvoiceTamil"; font-style: normal; font-weight: 700; src: url(data:font/woff2;base64,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) format("woff2"); }
    * { 
      margin: 0; 
      padding: 0; 
      box-sizing: border-box; 
    }
    
    @page {
      size: A4;
      margin: 0;
    }
    
    @page :first {
      margin-bottom: 15mm; /* Bottom padding on first page */
    }
    
    @page :not(:first) {
      margin-top: 20mm; /* Top padding on subsequent pages to prevent item break */
      margin-bottom: 15mm; /* Bottom padding on all pages */
    }
    
    html {
      width: ${shareMode ? pageWidth : 'auto'}px;
      ${shareMode ? 'overflow-x: hidden;' : ''}
    }
    
    body { 
      font-family: 'Arial', 'Helvetica', sans-serif;
      background: #ffffff;
      color: #000000;
      line-height: 1.6;
      margin: 0;
      padding: 0;
      width: ${shareMode ? pageWidth : 'auto'}px;
      ${shareMode ? 'overflow-x: hidden;' : ''}
    }
    
    .invoice-container {
      width: ${shareMode ? pageWidth : 'auto'}px;
      ${shareMode ? `padding: ${pagePadding}px; padding-top: 15mm; padding-bottom: 40mm;` : 'max-width: 1000px; padding: 40px; padding-bottom: 40px;'}
      box-sizing: border-box;
      margin: 0 auto;
      background: #ffffff;
      ${shareMode ? 'min-height: 100vh;' : ''}
    }
    
    /* Header Section */
    .invoice-header {
      padding-bottom: 20px;
      border-bottom: 4px solid #004D40;
      margin-bottom: 30px;
      width: 100%;
    }
    
    .company-info h1 {
      font-size: ${shareMode ? '28px' : '36px'};
      color: #004D40;
      font-weight: 700;
      margin-bottom: 8px;
      letter-spacing: 0.5px;
      white-space: nowrap;
    }
    
    .company-info .subtitle {
      color: #2E7D32;
      font-size: ${shareMode ? '14px' : '16px'};
      font-weight: 600;
      margin-bottom: 8px;
    }
    
    .company-info .phone-numbers {
      color: #000000;
      font-size: ${shareMode ? '13px' : '15px'};
      font-weight: 600;
      margin: 12px 0 8px 0;
    }
    
    .company-info .gst-number {
      color: #004D40;
      font-size: ${shareMode ? '12px' : '14px'};
      font-weight: 600;
      margin: 8px 0;
    }
    
    .company-info .address {
      color: #555555;
      font-size: ${shareMode ? '12px' : '14px'};
      line-height: 1.8;
    }
    
    /* Invoice Details Section */
    .invoice-details {
      display: flex;
      justify-content: space-between;
      margin-bottom: 30px;
      gap: 30px;
      width: 100%;
    }
    
    .bill-to,
    .invoice-meta {
      flex: 1;
    }
    
    .section-title {
      font-size: ${shareMode ? '14px' : '17px'};
      color: #004D40;
      font-weight: 700;
      margin-bottom: 12px;
      text-transform: uppercase;
      letter-spacing: 0.5px;
    }
    
    .invoice-details p {
      font-size: ${shareMode ? '12px' : '14px'};
      margin: 6px 0;
      line-height: 1.6;
    }

    .invoice-meta {
      text-align: right;
    }
    
    .invoice-meta p strong {
      color: #004D40;
    }
    
    /* Items Table */
    .items-table {
      width: 100%;
      border-collapse: collapse;
      margin: 25px 0;
    }
    
    .items-table thead {
      background: linear-gradient(135deg, #004D40 0%, #00695C 100%);
    }
    
    .items-table thead th {
      color: #ffffff;
      font-size: ${shareMode ? '11px' : '14px'};
      font-weight: 700;
      text-align: left;
      padding: ${shareMode ? '10px 8px' : '14px 10px'};
      text-transform: uppercase;
      letter-spacing: 0.5px;
      border: none;
    }
    
    .items-table thead th:first-child {
      width: 50px;
      text-align: center;
    }
    
    .items-table thead th:nth-child(3),
    .items-table thead th:nth-child(4),
    .items-table thead th:nth-child(5),
    .items-table thead th:nth-child(6) {
      text-align: right;
    }
    
    .items-table tbody tr {
      border-bottom: 1px solid #E0E0E0;
      page-break-inside: avoid !important;
      break-inside: avoid !important;
      min-height: ${shareMode ? '40px' : '45px'}; /* Minimum row height for consistent spacing */
    }
    
    .items-table tbody tr:hover {
      background: #F5F5F5;
    }
    
    .items-table tbody td {
      padding: ${shareMode ? '12px 8px' : '14px 10px'}; /* Increased padding for better spacing */
      font-size: ${shareMode ? '11px' : '14px'};
      color: #212121;
      vertical-align: middle;
      page-break-inside: avoid !important;
      break-inside: avoid !important;
    }
    
    .items-table tbody td:first-child {
      text-align: center;
      font-weight: 600;
      color: #004D40;
    }
    
    .items-table tbody td:nth-child(2) {
      font-weight: 500;
    }
    
    .items-table tbody td:nth-child(3),
    .items-table tbody td:nth-child(4),
    .items-table tbody td:nth-child(5),
    .items-table tbody td:nth-child(6) {
      text-align: right;
    }
    
    /* Page break control for share mode (same as print) */
    ${shareMode ? `
    .invoice-header,
    .invoice-details,
    .items-table thead,
    .items-table tbody tr,
    .total-section,
    .invoice-footer {
      page-break-inside: avoid;
    }
    ` : ''}
    
    /* Total Section */
    .total-section {
      margin-top: 30px;
      ${shareMode ? 'margin-bottom: 20mm;' : ''} /* Increased spacing */
      padding: 20px;
      background: #F5F5F5;
      border: 2px solid #004D40;
      border-radius: 8px;
      text-align: right;
      width: 100%;
      box-sizing: border-box;
    }
    
    .total-section .grand-total {
      font-size: ${shareMode ? '20px' : '28px'};
      color: #004D40;
      font-weight: 700;
      letter-spacing: 0.5px;
    }
    
    .total-section .total-label {
      font-size: ${shareMode ? '13px' : '16px'};
      color: #555555;
      margin-right: 15px;
    }
    
    /* Invoice section headings (Ordered Items / Return Items) */
    .invoice-section-heading {
      font-size: ${shareMode ? '14px' : '17px'};
      color: #004D40;
      font-weight: 700;
      margin: 25px 0 8px 0;
      text-transform: uppercase;
      letter-spacing: 0.5px;
    }
    
    .invoice-section-heading.return-section-heading {
      color: #F57C00;
    }
    
    /* Return Items Total Section */
    .return-total-section {
      margin-top: 20px;
      padding: 16px;
      background: #FFF3E0;
      border: 2px solid #F57C00;
      border-radius: 8px;
      text-align: right;
      width: 100%;
      box-sizing: border-box;
    }
    
    .return-total-section .return-grand-total {
      font-size: ${shareMode ? '18px' : '24px'};
      color: #F57C00;
      font-weight: 700;
      letter-spacing: 0.5px;
    }
    
    .return-total-section .total-label {
      font-size: ${shareMode ? '13px' : '16px'};
      color: #555555;
      margin-right: 15px;
    }
    
    /* Balance Section (shown above Return/Ordered items on the invoice) */
    .balance-section {
      margin-top: 20px;
      padding: 18px;
      border: 2px solid #2E7D32;
      border-radius: 8px;
      width: 100%;
      box-sizing: border-box;
      font-family: 'InvoiceTamil', 'Noto Sans Tamil', 'Arial', 'Helvetica', sans-serif;
    }
    
    .balance-section .balance-row {
      display: flex;
      justify-content: space-between;
      align-items: center;
      font-size: ${shareMode ? '13px' : '15px'};
      padding: 4px 0;
      color: #333333;
      font-family: 'InvoiceTamil', 'Noto Sans Tamil', 'Arial', 'Helvetica', sans-serif;
    }
    
    .balance-section .balance-row.grand {
      border-top: 2px solid #2E7D32;
      margin-top: 6px;
      padding-top: 8px;
      font-weight: 700;
      font-size: ${shareMode ? '15px' : '18px'};
      color: #2E7D32;
    }
    
    .balance-section .balance-label {
      font-weight: 600;
      color: #555555;
    }
    
    .balance-section .balance-value {
      font-weight: 700;
    }
    
    .balance-section-heading {
      font-size: ${shareMode ? '14px' : '17px'};
      color: #2E7D32;
      font-weight: 700;
      margin: 25px 0 8px 0;
      text-transform: uppercase;
      letter-spacing: 0.5px;
      font-family: 'InvoiceTamil', 'Noto Sans Tamil', 'Arial', 'Helvetica', sans-serif;
    }
    
    /* Footer - Acts as white space at bottom of each page */
    .invoice-footer {
      margin-top: 50px;
      padding-top: 0;
      ${shareMode ? 'padding-bottom: 20mm;' : ''} /* White space */
      border-top: none; /* Remove border */
      text-align: center;
      width: 100%;
      background: transparent; /* Ensure white space */
    }
    
    .invoice-footer p {
      display: none; /* Hide any text */
    }
    
    .invoice-footer .thank-you {
      display: none; /* Hide any text */
    }
    
    /* Print Styles */
    @media print {
      @page {
        size: A4;
        margin: 0;
      }
      
      @page :first {
        margin-bottom: 15mm; /* Bottom padding on first page */
      }
      
      @page :not(:first) {
        margin-top: 20mm; /* Top padding on subsequent pages to prevent item break */
        margin-bottom: 15mm; /* Bottom padding on all pages */
      }
      
      body {
        width: 210mm;
        margin: 0;
        padding: 0;
      }
      
      .invoice-container {
        width: 100%;
        max-width: 100%;
        padding: 15mm;
        padding-bottom: 0; /* Remove container padding-bottom, using @page margin instead */
      }
      
      .items-table tbody tr:hover {
        background: transparent;
      }
      
      /* Aggressive page break controls */
      .invoice-header,
      .invoice-details,
      .items-table thead,
      .items-table tbody tr,
      .total-section,
      .invoice-footer {
        page-break-inside: avoid !important;
        break-inside: avoid !important; /* Modern CSS */
      }
      
      /* Prevent orphan rows */
      .items-table tbody tr {
        page-break-after: auto;
        break-after: auto;
      }
      
      /* Keep last few rows together with total */
      .items-table tbody tr:nth-last-child(-n+3) {
        page-break-after: avoid !important;
        break-after: avoid !important;
      }
      
      .total-section {
        margin-bottom: 5mm; /* Reduced margin since using @page margins */
        page-break-before: avoid !important;
        break-before: avoid !important;
      }
      
      .invoice-footer {
        padding-bottom: 0; /* Remove padding, using @page margin instead */
        border-top: none; /* No border */
        page-break-before: avoid !important;
        break-before: avoid !important;
      }
      
      /* Add page break after large tables */
      .items-table tbody tr:nth-child(15) {
        page-break-after: auto;
      }
    }
  </style>
</head>
<body>
  <div class="invoice-container">
    <!-- Header -->
    <div class="invoice-header">
      <div class="company-info">
        <h1>அல் மதீனா ஏஜென்சீஸ்</h1>
        <div class="subtitle">மொத்தவிற்பனை மளிகை மற்றும் ஆயில்</div>
        <div class="phone-numbers">7339651541, 8754144759, 8870503350</div>
        <div class="gst-number">GST No: 33DLEPM3331L1Z5</div>
        <div class="address">
          பாரிநகர் 2வது தெரு, அன்னா நகர்,<br/>
          வடக்கு காட்டூர், திருச்சி - 620019.
        </div>
      </div>
    </div>
    
    <!-- Invoice Details -->
    <div class="invoice-details">
      <div class="bill-to">
        <h3 class="section-title">Bill To:</h3>
        <p><strong>${order.user_name || 'Customer'}</strong></p>
        <p>Phone: ${order.user_phone}</p>
        ${order.user_store_name ? `<p>Store: ${order.user_store_name}</p>` : ''}
        ${order.user_store_address && (order.user_store_address.street || order.user_store_address.city) ? `
          <p style="margin-top: 10px;">
            ${order.user_store_address.street || ''}<br/>
            ${order.user_store_address.city || ''}, ${order.user_store_address.state || ''}<br/>
            ${order.user_store_address.pincode || ''}
          </p>
        ` : order.delivery_address && (order.delivery_address.street || order.delivery_address.city) ? `
          <p style="margin-top: 10px;">
            ${order.delivery_address.street || ''}<br/>
            ${order.delivery_address.city || ''}, ${order.delivery_address.state || ''}<br/>
            ${order.delivery_address.pincode || ''}
          </p>
        ` : ''}
      </div>
      
      <div class="invoice-meta">
        <h3 class="section-title">Invoice Details</h3>
        <p><strong>Order ID:</strong> ${order.order_id}</p>
        <p><strong>Date:</strong> ${formatDateTime(order.created_at)}</p>
        <p><strong>Payment:</strong> ${order.payment_method || 'COD'}</p>
      </div>
    </div>

    <!-- Balance Summary -->
    ${order.is_store_order ? `
    <h2 class="balance-section-heading">${balanceLabels.heading}</h2>
    <div class="balance-section">
      <div class="balance-row">
        <span class="balance-label">${balanceLabels.beforeOrder}</span>
        <span class="balance-value">₹${formatInvoiceCurrency(order.balance_before)}</span>
      </div>
      <div class="balance-row">
        <span class="balance-label">${balanceLabels.orderAmount}</span>
        <span class="balance-value">₹${formatInvoiceCurrency(order.order_amount != null ? order.order_amount : order.total_amount)}</span>
      </div>
      <div class="balance-row grand">
        <span class="balance-label">${balanceLabels.totalOutstanding}</span>
        <span class="balance-value">₹${formatInvoiceCurrency(order.balance_total)}</span>
      </div>
    </div>
    ` : ''}

    ${order.return_items && order.return_items.length > 0 ? `
    <!-- Return Items -->
    <h2 class="invoice-section-heading return-section-heading">Return Items</h2>
    <table class="items-table">
      <thead>
        <tr>
          <th>#</th>
          <th>Product Name</th>
          <th>Weight</th>
          <th>Price</th>
          <th>Qty</th>
          <th>Total</th>
        </tr>
      </thead>
      <tbody>
        ${order.return_items.map((item, index) => `
          <tr>
            <td>${index + 1}</td>
            <td>${item.product_name}</td>
            <td>${item.weight || '-'}</td>
            <td>₹${parseFloat(item.price).toFixed(2)}</td>
            <td>${item.quantity}</td>
            <td>₹${(item.price * item.quantity).toFixed(2)}</td>
          </tr>
        `).join('')}
      </tbody>
    </table>
    
    <!-- Return Items Total -->
    <div class="return-total-section">
      <span class="total-label">RETURN ITEMS TOTAL:</span>
      <span class="return-grand-total">₹${parseFloat(order.return_total || 0).toFixed(2)}</span>
    </div>
    ` : ''}
    
    <!-- Ordered Items -->
    <h2 class="invoice-section-heading">Ordered Items</h2>
    <table class="items-table">
      <thead>
        <tr>
          <th>#</th>
          <th>Product Name</th>
          <th>Weight</th>
          <th>Price</th>
          <th>Qty</th>
          <th>Total</th>
        </tr>
      </thead>
      <tbody>
        ${order.items.map((item, index) => `
          <tr>
            <td>${index + 1}</td>
            <td>${item.product_name}</td>
            <td>${item.weight || '-'}</td>
            <td>₹${parseFloat(item.price).toFixed(2)}</td>
            <td>${item.quantity}</td>
            <td>₹${(item.price * item.quantity).toFixed(2)}</td>
          </tr>
        `).join('')}
      </tbody>
    </table>
    
    <!-- Total -->
    <div class="total-section">
      <span class="total-label">ORDER TOTAL:</span>
      <span class="grand-total">₹${parseFloat(order.total_amount).toFixed(2)}</span>
    </div>
    
    <!-- Footer - Empty white space for page padding -->
    <div class="invoice-footer"></div>
  </div>
  
  ${printMode ? `<script>window.onload = () => setTimeout(() => window.print(), 200);</script>` : ''}
</body>
</html>`;
}

// Filter orders
function filterOrders() {
    console.log('🔍 filterOrders() called');

    try {
        // Guard: Check if allOrders exists and is an array
        if (!allOrders || !Array.isArray(allOrders)) {
            console.error('❌ allOrders is not defined or not an array!');
            return;
        }

        // Get search input
        const searchInput = document.getElementById('searchInput') || document.getElementById('orderSearch');
        const searchTerm = searchInput?.value?.toLowerCase().trim() || '';

        // Get status filter
        const statusFilterElement = document.getElementById('statusFilter');
        const statusFilter = statusFilterElement?.value || '';

        console.log(`   Filtering ${allOrders.length} orders - Search: "${searchTerm}", Status: "${statusFilter}"`);

        // Update URL with search parameters for automation
        const url = new URL(window.location);
        if (searchTerm) {
            url.searchParams.set('search', searchTerm);
        } else {
            url.searchParams.delete('search');
        }
        if (statusFilter) {
            url.searchParams.set('status', statusFilter);
        } else {
            url.searchParams.delete('status');
        }
        window.history.replaceState({}, '', url);

        // Update clear button visibility
        updateClearButtonVisibility();

        // Filter orders
        let filtered = allOrders.filter((order, index) => {
            try {
                // Skip if order is null or undefined
                if (!order) {
                    return false;
                }

                // Safely handle null/undefined values
                const orderId = order.order_id ? String(order.order_id).toLowerCase() : '';
                const userName = order.user_name ? String(order.user_name).toLowerCase() : '';
                const userPhone = order.user_phone ? String(order.user_phone).toLowerCase() : '';
                const storeName = order.user_store_name ? String(order.user_store_name).toLowerCase() : '';
                const orderStatus = order.status ? String(order.status).toLowerCase() : '';

                // Match search term against multiple fields
                const matchesSearch = !searchTerm ||
                    orderId.includes(searchTerm) ||
                    userName.includes(searchTerm) ||
                    userPhone.includes(searchTerm) ||
                    storeName.includes(searchTerm);

                // Match status filter
                const matchesStatus = !statusFilter || orderStatus === statusFilter.toLowerCase();

                // Match date filter
                const matchesDate = matchesDateFilter(order);

                return matchesSearch && matchesStatus && matchesDate;
            } catch (orderError) {
                console.error(`❌ Error processing order at index ${index}:`, orderError);
                return false;
            }
        });

        console.log(`   ✅ Filtered: ${filtered.length} orders match criteria`);

        // Store filtered orders globally
        filteredOrders = filtered;

        // Display filtered results
        displayOrders(filtered);

        // Update stats based on filtered orders
        updateFilteredStats(filtered);

    } catch (error) {
        console.error('❌ FATAL ERROR in filterOrders:', error);
        console.error('   Error stack:', error.stack);
    }
}

// Update statistics based on filtered orders
function updateFilteredStats(orders) {
    // Guard: Check if orders is valid
    if (!orders || !Array.isArray(orders)) {
        console.warn('⚠️  updateFilteredStats: orders is not valid');
        return;
    }

    try {
        const pending = orders.filter(o => o && o.status === 'pending').length;
        const delivered = orders.filter(o => o && o.status === 'delivered').length;
        const totalRevenue = orders.reduce((sum, o) => {
            if (!o) return sum;
            return sum + parseFloat(o.total_amount || 0);
        }, 0);

        const totalOrdersEl = document.getElementById('totalOrders');
        const pendingOrdersEl = document.getElementById('pendingOrders');
        const deliveredOrdersEl = document.getElementById('deliveredOrders');
        const totalRevenueEl = document.getElementById('totalRevenue');

        if (totalOrdersEl) totalOrdersEl.textContent = orders.length;
        if (pendingOrdersEl) pendingOrdersEl.textContent = pending;
        if (deliveredOrdersEl) deliveredOrdersEl.textContent = delivered;
        if (totalRevenueEl) totalRevenueEl.textContent = `₹${totalRevenue.toFixed(2)}`;

        // Update revenue modal if it's open
        updateRevenueModalIfOpen(orders);
    } catch (error) {
        console.error('❌ Error in updateFilteredStats:', error);
    }
}

// Update order statistics
async function updateOrderStats() {
    try {
        const response = await fetch('/api/admin/orders/stats/summary');
        const data = await response.json();

        if (data.success) {
            const stats = data.stats;

            // Update stat cards
            document.getElementById('totalOrders').textContent = stats.total_orders;
            document.getElementById('pendingOrders').textContent = stats.pending_orders;
            document.getElementById('deliveredOrders').textContent = stats.delivered_orders;
            document.getElementById('totalRevenue').textContent = `₹${stats.total_revenue.toFixed(2)}`;
        }
    } catch (error) {
        console.error('Error loading stats:', error);
    }
}

// Close modal
function closeOrderDetailsModal() {
    document.getElementById('orderDetailsModal').style.display = 'none';
    currentOrder = null;
}

// Get filtered orders based on current date filter
function getFilteredOrders() {
    let ordersToCalculate = allOrders;

    // Apply date filter if active
    const dateFilterBtn = document.querySelector('.date-filter-btn');
    if (dateFilterBtn && dateFilterBtn.textContent.includes('Single Date')) {
        const selectedDate = dateFilterBtn.getAttribute('data-date');
        if (selectedDate) {
            ordersToCalculate = allOrders.filter(order => {
                const orderDate = new Date(order.created_at).toISOString().split('T')[0];
                return orderDate === selectedDate;
            });
        }
    } else if (dateFilterBtn && dateFilterBtn.textContent.includes('Date Range')) {
        const startDate = dateFilterBtn.getAttribute('data-start');
        const endDate = dateFilterBtn.getAttribute('data-end');
        if (startDate && endDate) {
            ordersToCalculate = allOrders.filter(order => {
                const orderDate = new Date(order.created_at).toISOString().split('T')[0];
                return orderDate >= startDate && orderDate <= endDate;
            });
        }
    }

    return ordersToCalculate;
}

// Calculate revenue breakdown
function calculateRevenueBreakdown(orders) {
    const totalRevenue = orders.reduce((sum, o) => sum + parseFloat(o.total_amount || 0), 0);
    const pendingRevenue = orders
        .filter(o => o.status === 'pending')
        .reduce((sum, o) => sum + parseFloat(o.total_amount || 0), 0);
    const deliveredRevenue = orders
        .filter(o => o.status === 'delivered')
        .reduce((sum, o) => sum + parseFloat(o.total_amount || 0), 0);

    return { totalRevenue, pendingRevenue, deliveredRevenue };
}

// Update date range display in revenue modal
function updateRevenueDateDisplay() {
    const dateRangeEl = document.getElementById('revenueDateRange');
    if (!dateRangeEl) return;

    const dateFilterBtn = document.querySelector('.date-filter-btn');
    if (dateFilterBtn) {
        const filterText = dateFilterBtn.textContent.trim();
        if (filterText.includes('Single Date')) {
            const selectedDate = dateFilterBtn.getAttribute('data-date');
            if (selectedDate) {
                const date = new Date(selectedDate);
                dateRangeEl.textContent = date.toLocaleDateString('en-US', { year: 'numeric', month: 'long', day: 'numeric' });
            }
        } else if (filterText.includes('Date Range')) {
            const startDate = dateFilterBtn.getAttribute('data-start');
            const endDate = dateFilterBtn.getAttribute('data-end');
            if (startDate && endDate) {
                const start = new Date(startDate);
                const end = new Date(endDate);
                dateRangeEl.textContent = `${start.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })} - ${end.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })}`;
            }
        } else {
            dateRangeEl.textContent = 'All Time';
        }
    } else {
        dateRangeEl.textContent = 'All Time';
    }
}

// Update revenue modal if it's currently open
function updateRevenueModalIfOpen(orders) {
    const modal = document.getElementById('revenueModal');
    if (!modal || modal.style.display === 'none') return;

    // Recalculate and update revenue values
    const { totalRevenue, pendingRevenue, deliveredRevenue } = calculateRevenueBreakdown(orders);

    const totalEl = document.getElementById('revenueTotalOrders');
    const pendingEl = document.getElementById('revenuePending');
    const deliveredEl = document.getElementById('revenueDelivered');

    if (totalEl) totalEl.textContent = `₹${totalRevenue.toFixed(2)}`;
    if (pendingEl) pendingEl.textContent = `₹${pendingRevenue.toFixed(2)}`;
    if (deliveredEl) deliveredEl.textContent = `₹${deliveredRevenue.toFixed(2)}`;

    // Update date display
    updateRevenueDateDisplay();
}

// Show revenue details modal
function showRevenueDetails() {
    const modal = document.getElementById('revenueModal');

    // Use currently filtered orders
    const ordersToCalculate = filteredOrders.length > 0 ? filteredOrders : allOrders;
    const { totalRevenue, pendingRevenue, deliveredRevenue } = calculateRevenueBreakdown(ordersToCalculate);

    // Update modal content
    document.getElementById('revenueTotalOrders').textContent = `₹${totalRevenue.toFixed(2)}`;
    document.getElementById('revenuePending').textContent = `₹${pendingRevenue.toFixed(2)}`;
    document.getElementById('revenueDelivered').textContent = `₹${deliveredRevenue.toFixed(2)}`;

    // Update date range display
    updateRevenueDateDisplay();

    modal.style.display = 'flex';
}

// Close revenue modal
function closeRevenueModal() {
    document.getElementById('revenueModal').style.display = 'none';
}

// Format date and time
function formatDateTime(dateString) {
    if (!dateString) return 'N/A';
    const date = new Date(dateString);
    const options = {
        year: 'numeric',
        month: 'short',
        day: 'numeric',
        hour: '2-digit',
        minute: '2-digit',
        hour12: true
    };
    return date.toLocaleString('en-US', options);
}

// Format a number as a currency amount string (2 decimal places)
function formatInvoiceCurrency(amount) {
    const value = parseFloat(amount);
    return isNaN(value) ? '0.00' : value.toFixed(2);
}

// Show loading state
function showLoading(containerId) {
    const container = document.getElementById(containerId);
    container.innerHTML = `
        <div class="loading">
            <div class="spinner"></div>
            <p>Loading orders...</p>
        </div>
    `;
}

// Show error state
function showError(containerId, message) {
    const container = document.getElementById(containerId);
    container.innerHTML = `
        <div class="error-state">
            <i class="fas fa-exclamation-triangle" style="font-size: 48px; color: #f44336;"></i>
            <h3>Error</h3>
            <p>${message}</p>
            <button onclick="loadOrders()" class="btn btn-primary">Retry</button>
        </div>
    `;
}

// Modal close on outside click
window.onclick = function (event) {
    const modal = document.getElementById('orderDetailsModal');
    if (event.target === modal) {
        closeOrderDetailsModal();
    }
}

// Clear search input
// Clear search input
function clearSearch() {
    try {
        const searchInput = document.getElementById('searchInput') || document.getElementById('orderSearch');
        if (searchInput) {
            searchInput.value = '';
            filterOrders();
            updateClearButtonVisibility();
        }
    } catch (error) {
        console.error('❌ Error in clearSearch:', error);
    }
}

// Reset all filters
function resetFilters() {
    console.log('🔄 Resetting all filters...');

    // Clear search
    const searchInput = document.getElementById('searchInput') || document.getElementById('orderSearch');
    if (searchInput) {
        searchInput.value = '';
    }

    // Reset status filter
    const statusFilter = document.getElementById('statusFilter');
    if (statusFilter) {
        statusFilter.value = '';
    }

    // Re-display all orders
    displayOrders(allOrders);

    // Update stats with all orders
    updateOrderStats();

    // Update clear button visibility
    updateClearButtonVisibility();

    console.log('   ✅ Filters reset');
}

// Update clear button visibility based on search input
function updateClearButtonVisibility() {
    const searchInput = document.getElementById('searchInput') || document.getElementById('orderSearch');
    const clearBtn = document.getElementById('clearSearchBtn');

    if (searchInput && clearBtn) {
        if (searchInput.value.trim()) {
            clearBtn.style.display = 'block';
        } else {
            clearBtn.style.display = 'none';
        }
    }
}

// Delete order function
async function deleteOrder(orderId) {
    console.log(`🗑️ Attempting to delete order: ${orderId}`);

    if (!confirm(`Are you sure you want to delete Order #${orderId}?\n\nThis action cannot be undone.`)) {
        console.log('   ❌ Deletion cancelled by user');
        return;
    }

    try {
        console.log(`   📡 Sending DELETE request for order ${orderId}...`);

        const response = await fetch(`/api/admin/orders/${orderId}`, {
            method: 'DELETE',
            headers: {
                'Content-Type': 'application/json'
            }
        });

        const data = await response.json();

        if (response.ok && data.success) {
            console.log(`   ✅ Order ${orderId} deleted successfully`);

            // Remove from allOrders array
            allOrders = allOrders.filter(order => order.order_id !== orderId);

            // Refresh display
            filterOrders();
            updateOrderStats();

            // Show success message
            showToast('Order deleted successfully', 'success');
        } else {
            throw new Error(data.message || 'Failed to delete order');
        }
    } catch (error) {
        console.error(`   ❌ Error deleting order ${orderId}:`, error);
        showToast('Error: ' + error.message, 'error');
    }
}

// Show toast notification
function showToast(message, type = 'info') {
    // Create toast element
    const toast = document.createElement('div');
    toast.className = `toast toast-${type}`;
    toast.innerHTML = `
        <i class="fas fa-${type === 'success' ? 'check-circle' : 'exclamation-circle'}"></i>
        <span>${message}</span>
    `;

    // Add to body
    document.body.appendChild(toast);

    // Show toast
    setTimeout(() => toast.classList.add('show'), 100);

    // Remove toast after 3 seconds
    setTimeout(() => {
        toast.classList.remove('show');
        setTimeout(() => toast.remove(), 300);
    }, 3000);
}

// ============ DATE FILTER FUNCTIONS ============

// Handle date filter dropdown change
function handleDateFilterChange() {
    const dateFilter = document.getElementById('dateFilter').value;

    if (dateFilter === 'all') {
        selectedDateFilter.type = 'all';
        selectedDateFilter.singleDate = null;
        selectedDateFilter.startDate = null;
        selectedDateFilter.endDate = null;
        document.getElementById('dateDisplayGroup').style.display = 'none';
        filterOrders();
    } else if (dateFilter === 'single') {
        openSingleDateModal();
    } else if (dateFilter === 'range') {
        openRangeDateModal();
    }
}

// Open single date picker modal
function openSingleDateModal() {
    const modal = document.getElementById('singleDateModal');
    const datePicker = document.getElementById('singleDatePicker');

    // Set max date to today
    const today = new Date().toISOString().split('T')[0];
    datePicker.max = today;

    // Set current value if exists
    if (selectedDateFilter.singleDate) {
        datePicker.value = selectedDateFilter.singleDate;
    } else {
        datePicker.value = today;
    }

    modal.style.display = 'block';
}

// Open date range picker modal
function openRangeDateModal() {
    const modal = document.getElementById('rangeDateModal');
    const startPicker = document.getElementById('startDatePicker');
    const endPicker = document.getElementById('endDatePicker');

    // Set max date to today
    const today = new Date().toISOString().split('T')[0];
    startPicker.max = today;
    endPicker.max = today;

    // Set current values if exist
    if (selectedDateFilter.startDate && selectedDateFilter.endDate) {
        startPicker.value = selectedDateFilter.startDate;
        endPicker.value = selectedDateFilter.endDate;
    } else {
        // Default to last 7 days
        const sevenDaysAgo = new Date();
        sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);
        startPicker.value = sevenDaysAgo.toISOString().split('T')[0];
        endPicker.value = today;
    }

    modal.style.display = 'block';
}

// Close date modals
function closeDateModal() {
    document.getElementById('singleDateModal').style.display = 'none';
    document.getElementById('rangeDateModal').style.display = 'none';

    // Reset dropdown if user cancels
    if (selectedDateFilter.type === 'all') {
        document.getElementById('dateFilter').value = 'all';
    }
}

// Apply single date filter
function applySingleDate() {
    const datePicker = document.getElementById('singleDatePicker');
    const selectedDate = datePicker.value;

    if (!selectedDate) {
        alert('Please select a date');
        return;
    }

    selectedDateFilter.type = 'single';
    selectedDateFilter.singleDate = selectedDate;
    selectedDateFilter.startDate = null;
    selectedDateFilter.endDate = null;

    // Update display
    const dateObj = new Date(selectedDate);
    const dateDisplay = dateObj.toLocaleDateString('en-US', {
        year: 'numeric',
        month: 'short',
        day: 'numeric'
    });
    document.getElementById('dateDisplay').textContent = dateDisplay;
    document.getElementById('dateDisplayGroup').style.display = 'block';

    closeDateModal();
    filterOrders();
}

// Apply date range filter
function applyDateRange() {
    const startPicker = document.getElementById('startDatePicker');
    const endPicker = document.getElementById('endDatePicker');
    const startDate = startPicker.value;
    const endDate = endPicker.value;

    if (!startDate || !endDate) {
        alert('Please select both start and end dates');
        return;
    }

    if (new Date(startDate) > new Date(endDate)) {
        alert('Start date must be before or equal to end date');
        return;
    }

    selectedDateFilter.type = 'range';
    selectedDateFilter.singleDate = null;
    selectedDateFilter.startDate = startDate;
    selectedDateFilter.endDate = endDate;

    // Update display
    const startObj = new Date(startDate);
    const endObj = new Date(endDate);
    const dateDisplay = `${startObj.toLocaleDateString('en-US', { month: 'short', day: 'numeric' })} - ${endObj.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })}`;
    document.getElementById('dateDisplay').textContent = dateDisplay;
    document.getElementById('dateDisplayGroup').style.display = 'block';

    closeDateModal();
    filterOrders();
}

// Clear date filter
function clearDateFilter() {
    selectedDateFilter.type = 'all';
    selectedDateFilter.singleDate = null;
    selectedDateFilter.startDate = null;
    selectedDateFilter.endDate = null;

    document.getElementById('dateFilter').value = 'all';
    document.getElementById('dateDisplayGroup').style.display = 'none';

    filterOrders();
}

// Check if order matches date filter
function matchesDateFilter(order) {
    if (selectedDateFilter.type === 'all') {
        return true;
    }

    const orderDate = new Date(order.created_at);
    orderDate.setHours(0, 0, 0, 0); // Reset to start of day for comparison

    if (selectedDateFilter.type === 'single') {
        const filterDate = new Date(selectedDateFilter.singleDate);
        filterDate.setHours(0, 0, 0, 0);
        return orderDate.getTime() === filterDate.getTime();
    }

    if (selectedDateFilter.type === 'range') {
        const startDate = new Date(selectedDateFilter.startDate);
        const endDate = new Date(selectedDateFilter.endDate);
        startDate.setHours(0, 0, 0, 0);
        endDate.setHours(23, 59, 59, 999); // End of day

        return orderDate >= startDate && orderDate <= endDate;
    }

    return true;
}

// ============ PRODUCT SEARCH AND ADD FUNCTIONS ============

let searchTimeout = null;
let allProducts = [];

// Search products from backend
async function searchProducts(query) {
    clearTimeout(searchTimeout);

    if (query.trim().length < 2) {
        document.getElementById('productSearchResults').style.display = 'none';
        return;
    }

    // Show loading indicator
    const resultsContainer = document.getElementById('productSearchResults');
    resultsContainer.innerHTML = '<div style="padding: 16px; text-align: center; color: #666;"><i class="fas fa-spinner fa-spin" style="margin-right: 8px;"></i>Searching...</div>';
    resultsContainer.style.display = 'block';

    searchTimeout = setTimeout(async () => {
        try {
            const response = await fetch(`/api/admin/orders/products/search?q=${encodeURIComponent(query)}`);
            const data = await response.json();

            if (data.success && data.products.length > 0) {
                displaySearchResults(data.products);
            } else {
                resultsContainer.innerHTML = `
                    <div style="padding: 20px; text-align: center; color: #666;">
                        <i class="fas fa-search" style="font-size: 32px; color: #ccc; margin-bottom: 8px;"></i>
                        <div style="font-size: 14px;">No products found for "${query}"</div>
                        <div style="font-size: 12px; color: #999; margin-top: 4px;">Try a different search term</div>
                    </div>
                `;
                resultsContainer.style.display = 'block';
            }
        } catch (error) {
            console.error('Error searching products:', error);
            resultsContainer.innerHTML = `
                <div style="padding: 20px; text-align: center; color: #f44336;">
                    <i class="fas fa-exclamation-triangle" style="font-size: 32px; margin-bottom: 8px;"></i>
                    <div style="font-size: 14px;">Error loading products</div>
                    <div style="font-size: 12px; color: #999; margin-top: 4px;">${error.message}</div>
                </div>
            `;
            resultsContainer.style.display = 'block';
        }
    }, 300);
}

// Display search results
function displaySearchResults(products) {
    const resultsContainer = document.getElementById('productSearchResults');

    resultsContainer.innerHTML = products.map((product, index) => {
        const tamilName = product.product_name_tamil || '';
        const displayName = tamilName ? `${product.product_name} / ${tamilName}` : product.product_name;
        const uniqueId = `product-${product.item_id}-${index}`;

        return `
            <div class="product-search-item" 
                style="padding: 12px 16px; border-bottom: 1px solid #e0e0e0; display: flex; justify-content: space-between; align-items: center; transition: background 0.2s; background: white;">
                <div style="flex: 1;">
                    <div style="margin-bottom: 4px;">
                        <strong style="color: #1B5E20; font-size: 14px;">${product.product_name}</strong>
                        ${tamilName ? `<span style="color: #666; font-size: 13px; margin-left: 6px;">/ ${tamilName}</span>` : ''}
                    </div>
                    <div style="font-size: 12px; color: #666; display: flex; align-items: center; gap: 12px;">
                        <span><i class="fas fa-weight-hanging" style="margin-right: 4px;"></i>${product.weight || 'N/A'}</span>
                        <span><i class="fas fa-rupee-sign" style="margin-right: 4px;"></i>${parseFloat(product.price).toFixed(2)}${product.unit ? '/' + product.unit : ''}</span>
                        ${(() => { const ep = calculateEffectivePrice(parseFloat(product.price), product.weight, product.unit || ''); return ep !== parseFloat(product.price) ? `<span style="color: #2E7D32; font-weight: 600;">→ ₹${ep.toFixed(2)}</span>` : ''; })()}
                        ${product.section ? `<span style="background: #E8F5E9; padding: 2px 8px; border-radius: 12px; color: #2E7D32; font-size: 11px;">${product.section}</span>` : ''}
                    </div>
                </div>
                <div style="display: flex; align-items: center; gap: 8px;">
                    <input type="number" 
                        id="qty-${uniqueId}" 
                        class="product-qty-input" 
                        placeholder="Qty" 
                        min="1" 
                        value=""
                        style="width: 70px; padding: 6px 8px; text-align: center; border: 2px solid #e0e0e0; border-radius: 6px; font-size: 14px; outline: none; transition: border-color 0.2s;"
                        oninput="toggleAddButton('${uniqueId}', this.value)"
                        onfocus="this.style.borderColor='#4CAF50'"
                        onblur="this.style.borderColor='#e0e0e0'">
                    <button 
                        id="btn-${uniqueId}" 
                        class="btn-add-product"
                        disabled
                        onclick="addProductToOrderWithQty('${product.item_id}', '${product.product_name.replace(/'/g, "\\'")}', '${product.weight || ''}', ${product.price}, '${uniqueId}', '${product.unit || ''}')"
                        style="background: #cccccc; color: white; border: none; padding: 8px 12px; border-radius: 50%; cursor: not-allowed; transition: all 0.2s; width: 36px; height: 36px; display: flex; align-items: center; justify-content: center;">
                        <i class="fas fa-plus" style="font-size: 16px;"></i>
                    </button>
                </div>
            </div>
        `;
    }).join('');

    resultsContainer.style.display = 'block';
}

// Toggle add button based on quantity input
function toggleAddButton(uniqueId, qtyValue) {
    const button = document.getElementById(`btn-${uniqueId}`);
    const qty = parseInt(qtyValue);

    if (qty && qty > 0) {
        button.disabled = false;
        button.style.background = '#4CAF50';
        button.style.cursor = 'pointer';
        button.style.boxShadow = '0 2px 4px rgba(76, 175, 80, 0.3)';
    } else {
        button.disabled = true;
        button.style.background = '#cccccc';
        button.style.cursor = 'not-allowed';
        button.style.boxShadow = 'none';
    }
}

// Add product to order with specified quantity
function addProductToOrderWithQty(itemId, productName, weight, price, uniqueId, unit) {
    const qtyInput = document.getElementById(`qty-${uniqueId}`);
    const quantity = parseInt(qtyInput.value) || 1;

    if (quantity <= 0) {
        showToast('Please enter a valid quantity', 'error');
        return;
    }

    // Calculate effective price based on weight
    const effectivePrice = calculateEffectivePrice(parseFloat(price), weight, unit || '');
    const tbody = document.querySelector('#orderItemsTable tbody');

    // Check if product already exists
    const existingRow = Array.from(tbody.querySelectorAll('tr')).find(row => {
        const existingName = row.querySelector('td:first-child strong')?.textContent;
        const existingWeight = row.dataset.weight;
        return existingName === productName && existingWeight === weight;
    });

    if (existingRow) {
        // Increment quantity if product already exists
        const qtyInputExisting = existingRow.querySelector('.qty-input');
        if (qtyInputExisting) {
            const currentQty = parseInt(qtyInputExisting.value) || 0;
            qtyInputExisting.value = currentQty + quantity;

            // Update display
            const qtyDisplay = existingRow.querySelector('.qty-display');
            if (qtyDisplay) qtyDisplay.textContent = `×${qtyInputExisting.value}`;

            // Recalculate totals
            updateItemTotal({ target: qtyInputExisting });
        }

        showToast(`Quantity increased for ${productName} (+${quantity})`, 'success');
    } else {
        // Add new row
        const newIndex = tbody.children.length;
        const newRow = document.createElement('tr');
        newRow.dataset.itemIndex = newIndex;
        newRow.dataset.productId = itemId;
        newRow.dataset.price = effectivePrice;
        newRow.dataset.weight = weight;
        newRow.dataset.unit = unit || '';

        const totalAmount = (effectivePrice * quantity).toFixed(2);

        newRow.innerHTML = `
            <td><strong>${productName}</strong></td>
            <td>${weight || '-'}</td>
            <td class="price-cell">
                <span class="price-display" style="display: none;">₹${effectivePrice.toFixed(2)}</span>
                <input type="number" class="price-input" value="${effectivePrice}" min="0" step="0.01" style="display: inline; width: 80px; padding: 4px; text-align: center; border: 2px solid #4CAF50;" data-original="${effectivePrice}">
            </td>
            <td class="qty-cell">
                <span class="qty-display" style="display: none;">×${quantity}</span>
                <input type="number" class="qty-input" value="${quantity}" min="1" style="display: inline; width: 60px; padding: 4px; text-align: center; border: 2px solid #4CAF50;" data-original="${quantity}">
            </td>
            <td class="item-total"><strong>₹${totalAmount}</strong></td>
            <td style="display: table-cell;" class="edit-only-column">
                <button class="btn-delete-item" onclick="removeOrderItem(this)" style="display: inline-block; background: #f44336; color: white; border: none; padding: 6px 12px; border-radius: 4px; cursor: pointer;" title="Remove item">
                    <i class="fas fa-trash"></i>
                </button>
            </td>
        `;

        tbody.appendChild(newRow);

        // Add event listeners to new inputs
        const priceInput = newRow.querySelector('.price-input');
        const qtyInputNew = newRow.querySelector('.qty-input');
        if (priceInput) priceInput.addEventListener('input', updateItemTotal);
        if (qtyInputNew) qtyInputNew.addEventListener('input', updateItemTotal);

        showToast(`${productName} (×${quantity}) added to order`, 'success');
    }

    // Clear search
    clearProductSearch();

    // Recalculate grand total
    recalculateGrandTotal();
}

// Remove item from order
function removeOrderItem(button) {
    if (!confirm('Are you sure you want to remove this item?')) {
        return;
    }

    const row = button.closest('tr');
    const productName = row.querySelector('td:first-child strong')?.textContent || 'Product';

    row.remove();
    recalculateGrandTotal();

    showToast(`${productName} removed from order`, 'info');
}

// ============ RETURN ITEMS EDITING FUNCTIONS ============
// Namespaced (Return*) mirror of the Order Items edit UX, operating on a
// separate #returnItemsTable and the /update-return-items endpoint. Returns
// never touch inventory or the real order amount.

// Open the return items editor (used when the order has no return items yet)
function openReturnItemsEditor() {
    returnSectionExpanded = true;
    returnIsEditMode = true;
    originalReturnItemsSnapshot = getReturnItemsFromTable();

    const tableContainer = document.getElementById('returnItemsTableContainer');
    if (tableContainer) tableContainer.style.display = 'block';

    const addProductContainer = document.getElementById('returnAddProductContainer');
    if (addProductContainer) addProductContainer.style.display = 'block';

    const saveContainer = document.getElementById('returnSaveButtonContainer');
    if (saveContainer) saveContainer.style.display = 'block';

    const addBtn = document.querySelector('.btn-add-return-items');
    if (addBtn) addBtn.style.display = 'none';

    document.querySelectorAll('.action-btn').forEach(btn => { btn.disabled = true; btn.style.opacity = '0.5'; btn.style.cursor = 'not-allowed'; });
}

// Toggle edit mode for return quantities
function toggleReturnEditMode() {
    returnIsEditMode = true;
    originalReturnItemsSnapshot = getReturnItemsFromTable();

    // Show quantity inputs
    document.querySelectorAll('.return-qty-display').forEach(el => el.style.display = 'none');
    document.querySelectorAll('.return-qty-input').forEach(el => {
        el.style.display = 'inline';
        el.style.width = '60px';
        el.style.padding = '4px';
        el.style.textAlign = 'center';
        el.style.border = '2px solid #F57C00';
    });

    // Show price inputs
    document.querySelectorAll('.return-price-display').forEach(el => el.style.display = 'none');
    document.querySelectorAll('.return-price-input').forEach(el => {
        el.style.display = 'inline';
        el.style.width = '80px';
        el.style.padding = '4px';
        el.style.textAlign = 'center';
        el.style.border = '2px solid #F57C00';
    });

    // Show add return product container
    const addProductContainer = document.getElementById('returnAddProductContainer');
    if (addProductContainer) addProductContainer.style.display = 'block';

    // Show delete buttons and action column
    document.querySelectorAll('.return-edit-only-column').forEach(el => el.style.display = 'table-cell');
    document.querySelectorAll('.btn-delete-return-item').forEach(btn => btn.style.display = 'inline-block');

    // Add event listeners
    document.querySelectorAll('.return-qty-input').forEach(input => input.addEventListener('input', updateReturnItemTotal));
    document.querySelectorAll('.return-price-input').forEach(input => input.addEventListener('input', updateReturnItemTotal));

    const saveContainer = document.getElementById('returnSaveButtonContainer');
    if (saveContainer) saveContainer.style.display = 'block';
    document.querySelectorAll('.action-btn').forEach(btn => { btn.disabled = true; btn.style.opacity = '0.5'; btn.style.cursor = 'not-allowed'; });
    const editBtn = document.querySelector('.btn-edit-return-items');
    if (editBtn) editBtn.style.display = 'none';
}

function cancelReturnEditMode() {
    returnIsEditMode = false;

    // Reset quantity inputs
    document.querySelectorAll('.return-qty-input').forEach(input => { input.value = input.dataset.original; input.style.display = 'none'; });
    document.querySelectorAll('.return-qty-display').forEach(el => el.style.display = 'inline');

    // Reset price inputs
    document.querySelectorAll('.return-price-input').forEach(input => { input.value = input.dataset.original; input.style.display = 'none'; });
    document.querySelectorAll('.return-price-display').forEach(el => el.style.display = 'inline');

    // Hide add return product container
    const addProductContainer = document.getElementById('returnAddProductContainer');
    if (addProductContainer) addProductContainer.style.display = 'none';
    clearReturnProductSearch();

    // Hide delete buttons and action column
    document.querySelectorAll('.return-edit-only-column').forEach(el => el.style.display = 'none');
    document.querySelectorAll('.btn-delete-return-item').forEach(btn => btn.style.display = 'none');

    const saveContainer = document.getElementById('returnSaveButtonContainer');
    if (saveContainer) saveContainer.style.display = 'none';
    document.querySelectorAll('.action-btn').forEach(btn => { btn.disabled = false; btn.style.opacity = '1'; btn.style.cursor = 'pointer'; });

    // If no return items remain and we were in expanded state, collapse back
    const rows = document.querySelectorAll('#returnItemsTable tbody tr');
    const tableContainer = document.getElementById('returnItemsTableContainer');
    if (rows.length === 0 && tableContainer && returnSectionExpanded) {
        returnSectionExpanded = false;
        tableContainer.style.display = 'none';
        const addBtn = document.querySelector('.btn-add-return-items');
        if (addBtn) addBtn.style.display = 'inline-block';
    } else {
        const editBtn = document.querySelector('.btn-edit-return-items');
        if (editBtn) editBtn.style.display = 'inline-block';
    }

    recalculateReturnGrandTotal();
}

function updateReturnItemTotal(event) {
    const input = event.target;
    const row = input.closest('tr');

    const priceInput = row.querySelector('.return-price-input');
    const price = priceInput ? parseFloat(priceInput.value) || 0 : parseFloat(row.dataset.price);

    const qtyInput = row.querySelector('.return-qty-input');
    const quantity = parseInt(qtyInput.value) || 0;

    const itemTotal = price * quantity;
    const totalCell = row.querySelector('.return-item-total strong');
    if (totalCell) totalCell.textContent = `₹${itemTotal.toFixed(2)}`;

    recalculateReturnGrandTotal();
}

function recalculateReturnGrandTotal() {
    let grandTotal = 0;
    document.querySelectorAll('#returnItemsTable tbody tr').forEach(row => {
        const priceInput = row.querySelector('.return-price-input');
        const price = priceInput ? (parseFloat(priceInput.value) || parseFloat(priceInput.dataset.original)) : parseFloat(row.dataset.price);

        const qtyInput = row.querySelector('.return-qty-input');
        const quantity = parseInt(qtyInput?.value) || parseInt(qtyInput?.dataset.original) || 0;

        grandTotal += price * quantity;
    });
    const totalEl = document.querySelector('.return-total-amount');
    if (totalEl) totalEl.textContent = `₹${grandTotal.toFixed(2)}`;
}

function getReturnItemsFromTable() {
    return Array.from(document.querySelectorAll('#returnItemsTable tbody tr')).map(row => {
        const qtyInput = row.querySelector('.return-qty-input');
        const priceInput = row.querySelector('.return-price-input');
        const weightText = (row.querySelector('td:nth-child(2)')?.textContent || '').trim();

        return {
            item_id: (row.dataset.productId || '').trim(),
            product_name: (row.querySelector('td:first-child strong')?.textContent || '').trim(),
            weight: weightText === '-' ? '' : weightText,
            price: parseFloat(priceInput?.value) || 0,
            quantity: parseInt(qtyInput?.value) || 0,
            unit: (row.dataset.unit || '').trim()
        };
    });
}

async function saveReturnItemsChanges(orderId) {
    const updatedItems = getReturnItemsFromTable();

    if (updatedItems.length === 0) {
        if (!confirm('No return items — this will clear the return record for this order. Continue?')) {
            return;
        }
    } else {
        if (!confirm('Are you sure you want to save these return items? This will update the return record for the order.')) {
            return;
        }
    }

    try {
        const response = await fetch(`/api/admin/orders/${orderId}/update-return-items`, {
            method: 'PUT',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                items: updatedItems
            })
        });

        const data = await response.json();

        if (response.ok) {
            alert('Return items updated successfully!');

            // Update current order data with response from server
            currentOrder.return_items = data.return_items || updatedItems;
            currentOrder.return_total = data.return_total || updatedItems.reduce((sum, item) => sum + (item.price * item.quantity), 0);

            // Re-render the order details with new data
            renderOrderDetails(currentOrder);

            // Exit return edit mode
            cancelReturnEditMode();

            // Refresh main order list in background
            loadOrders();
        } else {
            throw new Error(data.error || 'Failed to update return items');
        }
    } catch (error) {
        console.error('Error updating return items:', error);
        alert('Error updating return items: ' + error.message);
    }
}

// Search return products from backend (namespaced for #returnProductSearchResults)
async function searchReturnProducts(query) {
    clearTimeout(searchTimeout);

    if (query.trim().length < 2) {
        document.getElementById('returnProductSearchResults').style.display = 'none';
        return;
    }

    // Show loading indicator
    const resultsContainer = document.getElementById('returnProductSearchResults');
    resultsContainer.innerHTML = '<div style="padding: 16px; text-align: center; color: #666;"><i class="fas fa-spinner fa-spin" style="margin-right: 8px;"></i>Searching...</div>';
    resultsContainer.style.display = 'block';

    searchTimeout = setTimeout(async () => {
        try {
            const response = await fetch(`/api/admin/orders/products/search?q=${encodeURIComponent(query)}`);
            const data = await response.json();

            if (data.success && data.products.length > 0) {
                displayReturnSearchResults(data.products);
            } else {
                resultsContainer.innerHTML = `
                    <div style="padding: 20px; text-align: center; color: #666;">
                        <i class="fas fa-search" style="font-size: 32px; color: #ccc; margin-bottom: 8px;"></i>
                        <div style="font-size: 14px;">No products found for "${query}"</div>
                        <div style="font-size: 12px; color: #999; margin-top: 4px;">Try a different search term</div>
                    </div>
                `;
                resultsContainer.style.display = 'block';
            }
        } catch (error) {
            console.error('Error searching return products:', error);
            resultsContainer.innerHTML = `
                <div style="padding: 20px; text-align: center; color: #f44336;">
                    <i class="fas fa-exclamation-triangle" style="font-size: 32px; margin-bottom: 8px;"></i>
                    <div style="font-size: 14px;">Error loading products</div>
                    <div style="font-size: 12px; color: #999; margin-top: 4px;">${error.message}</div>
                </div>
            `;
            resultsContainer.style.display = 'block';
        }
    }, 300);
}

// Display return search results
function displayReturnSearchResults(products) {
    const resultsContainer = document.getElementById('returnProductSearchResults');

    resultsContainer.innerHTML = products.map((product, index) => {
        const tamilName = product.product_name_tamil || '';
        const displayName = tamilName ? `${product.product_name} / ${tamilName}` : product.product_name;
        const uniqueId = `return-product-${product.item_id}-${index}`;

        return `
            <div class="product-search-item"
                style="padding: 12px 16px; border-bottom: 1px solid #e0e0e0; display: flex; justify-content: space-between; align-items: center; transition: background 0.2s; background: white;">
                <div style="flex: 1;">
                    <div style="margin-bottom: 4px;">
                        <strong style="color: #E65100; font-size: 14px;">${product.product_name}</strong>
                        ${tamilName ? `<span style="color: #666; font-size: 13px; margin-left: 6px;">/ ${tamilName}</span>` : ''}
                    </div>
                    <div style="font-size: 12px; color: #666; display: flex; align-items: center; gap: 12px;">
                        <span><i class="fas fa-weight-hanging" style="margin-right: 4px;"></i>${product.weight || 'N/A'}</span>
                        <span><i class="fas fa-rupee-sign" style="margin-right: 4px;"></i>${parseFloat(product.price).toFixed(2)}${product.unit ? '/' + product.unit : ''}</span>
                        ${(() => { const ep = calculateEffectivePrice(parseFloat(product.price), product.weight, product.unit || ''); return ep !== parseFloat(product.price) ? `<span style="color: #2E7D32; font-weight: 600;">→ ₹${ep.toFixed(2)}</span>` : ''; })()}
                        ${product.section ? `<span style="background: #FFF3E0; padding: 2px 8px; border-radius: 12px; color: #E65100; font-size: 11px;">${product.section}</span>` : ''}
                    </div>
                </div>
                <div style="display: flex; align-items: center; gap: 8px;">
                    <input type="number"
                        id="qty-${uniqueId}"
                        class="product-qty-input"
                        placeholder="Qty"
                        min="1"
                        value=""
                        style="width: 70px; padding: 6px 8px; text-align: center; border: 2px solid #e0e0e0; border-radius: 6px; font-size: 14px; outline: none; transition: border-color 0.2s;"
                        oninput="toggleReturnAddButton('${uniqueId}', this.value)"
                        onfocus="this.style.borderColor='#F57C00'"
                        onblur="this.style.borderColor='#e0e0e0'">
                    <button
                        id="btn-${uniqueId}"
                        class="btn-add-product"
                        disabled
                        onclick="addReturnProductToOrderWithQty('${product.item_id}', '${product.product_name.replace(/'/g, "\\'")}', '${product.weight || ''}', ${product.price}, '${uniqueId}', '${product.unit || ''}')"
                        style="background: #cccccc; color: white; border: none; padding: 8px 12px; border-radius: 50%; cursor: not-allowed; transition: all 0.2s; width: 36px; height: 36px; display: flex; align-items: center; justify-content: center;">
                        <i class="fas fa-plus" style="font-size: 16px;"></i>
                    </button>
                </div>
            </div>
        `;
    }).join('');

    resultsContainer.style.display = 'block';
}

// Toggle return add button based on quantity input
function toggleReturnAddButton(uniqueId, qtyValue) {
    const button = document.getElementById(`btn-${uniqueId}`);
    const qty = parseInt(qtyValue);

    if (qty && qty > 0) {
        button.disabled = false;
        button.style.background = '#F57C00';
        button.style.cursor = 'pointer';
        button.style.boxShadow = '0 2px 4px rgba(245, 124, 0, 0.3)';
    } else {
        button.disabled = true;
        button.style.background = '#cccccc';
        button.style.cursor = 'not-allowed';
        button.style.boxShadow = 'none';
    }
}

// Add product to return with specified quantity
function addReturnProductToOrderWithQty(itemId, productName, weight, price, uniqueId, unit) {
    const qtyInput = document.getElementById(`qty-${uniqueId}`);
    const quantity = parseInt(qtyInput.value) || 1;

    if (quantity <= 0) {
        showToast('Please enter a valid quantity', 'error');
        return;
    }

    // Calculate effective price based on weight
    const effectivePrice = calculateEffectivePrice(parseFloat(price), weight, unit || '');
    const tbody = document.querySelector('#returnItemsTable tbody');

    // Check if product already exists
    const existingRow = Array.from(tbody.querySelectorAll('tr')).find(row => {
        const existingName = row.querySelector('td:first-child strong')?.textContent;
        const existingWeight = row.dataset.weight;
        return existingName === productName && existingWeight === weight;
    });

    if (existingRow) {
        // Increment quantity if product already exists
        const qtyInputExisting = existingRow.querySelector('.return-qty-input');
        if (qtyInputExisting) {
            const currentQty = parseInt(qtyInputExisting.value) || 0;
            qtyInputExisting.value = currentQty + quantity;

            // Update display
            const qtyDisplay = existingRow.querySelector('.return-qty-display');
            if (qtyDisplay) qtyDisplay.textContent = `×${qtyInputExisting.value}`;

            // Recalculate totals
            updateReturnItemTotal({ target: qtyInputExisting });
        }

        showToast(`Quantity increased for ${productName} (+${quantity})`, 'success');
    } else {
        // Add new row
        const newIndex = tbody.children.length;
        const newRow = document.createElement('tr');
        newRow.dataset.itemIndex = newIndex;
        newRow.dataset.productId = itemId;
        newRow.dataset.price = effectivePrice;
        newRow.dataset.weight = weight;
        newRow.dataset.unit = unit || '';

        const totalAmount = (effectivePrice * quantity).toFixed(2);

        newRow.innerHTML = `
            <td><strong>${productName}</strong></td>
            <td>${weight || '-'}</td>
            <td class="return-price-cell">
                <span class="return-price-display" style="display: none;">₹${effectivePrice.toFixed(2)}</span>
                <input type="number" class="return-price-input" value="${effectivePrice}" min="0" step="0.01" style="display: inline; width: 80px; padding: 4px; text-align: center; border: 2px solid #F57C00;" data-original="${effectivePrice}">
            </td>
            <td class="return-qty-cell">
                <span class="return-qty-display" style="display: none;">×${quantity}</span>
                <input type="number" class="return-qty-input" value="${quantity}" min="1" style="display: inline; width: 60px; padding: 4px; text-align: center; border: 2px solid #F57C00;" data-original="${quantity}">
            </td>
            <td class="return-item-total"><strong>₹${totalAmount}</strong></td>
            <td style="display: table-cell;" class="return-edit-only-column">
                <button class="btn-delete-return-item" onclick="removeReturnItem(this)" style="display: inline-block; background: #f44336; color: white; border: none; padding: 6px 12px; border-radius: 4px; cursor: pointer;" title="Remove item">
                    <i class="fas fa-trash"></i>
                </button>
            </td>
        `;

        tbody.appendChild(newRow);

        // Add event listeners to new inputs
        const priceInput = newRow.querySelector('.return-price-input');
        const qtyInputNew = newRow.querySelector('.return-qty-input');
        if (priceInput) priceInput.addEventListener('input', updateReturnItemTotal);
        if (qtyInputNew) qtyInputNew.addEventListener('input', updateReturnItemTotal);

        showToast(`${productName} (×${quantity}) added to return`, 'success');
    }

    // Clear search
    clearReturnProductSearch();

    // Recalculate return grand total
    recalculateReturnGrandTotal();
}

// Remove item from return
function removeReturnItem(button) {
    if (!confirm('Are you sure you want to remove this item?')) {
        return;
    }

    const row = button.closest('tr');
    const productName = row.querySelector('td:first-child strong')?.textContent || 'Product';

    row.remove();
    recalculateReturnGrandTotal();

    showToast(`${productName} removed from return`, 'info');
}

// Clear return product search
function clearReturnProductSearch() {
    const input = document.getElementById('returnProductSearchInput');
    const results = document.getElementById('returnProductSearchResults');
    if (input) input.value = '';
    if (results) {
        results.style.display = 'none';
        results.innerHTML = '';
    }
}

// ============ BULK ORDER SELECTION FUNCTIONS ============

// Toggle order selection
function toggleOrderSelection(orderId, isChecked) {
    if (isChecked) {
        selectedOrderIds.add(orderId);
    } else {
        selectedOrderIds.delete(orderId);
    }
    updateBulkActionButton();
}

// Select all pending orders that are currently displayed
function selectAllPendings() {
    // Get all currently displayed order cards
    const orderCards = document.querySelectorAll('.order-card');

    let selectedCount = 0;
    orderCards.forEach(card => {
        const orderId = card.getAttribute('data-order-id');
        const checkbox = document.getElementById(`checkbox-${orderId}`);

        // Only select if checkbox exists (not delivered) and is pending status
        if (checkbox) {
            const statusBadge = card.querySelector('.status-badge');
            const status = statusBadge ? statusBadge.textContent.trim().toLowerCase() : '';

            if (status === 'pending') {
                checkbox.checked = true;
                selectedOrderIds.add(orderId);
                selectedCount++;
            }
        }
    });

    updateBulkActionButton();

    // Show feedback
    if (selectedCount > 0) {
        showToast(`Selected ${selectedCount} pending order${selectedCount > 1 ? 's' : ''}`, 'success');
    } else {
        showToast('No pending orders found in currently loaded orders', 'info');
    }
}

// Update bulk action button visibility and count
function updateBulkActionButton() {
    let bulkActionBtn = document.getElementById('bulkMarkDeliveredBtn');

    if (selectedOrderIds.size > 0) {
        // Create button if it doesn't exist
        if (!bulkActionBtn) {
            bulkActionBtn = document.createElement('button');
            bulkActionBtn.id = 'bulkMarkDeliveredBtn';
            bulkActionBtn.className = 'bulk-action-btn';
            bulkActionBtn.onclick = markSelectedAsDelivered;

            // Insert after orders header
            const ordersHeader = document.querySelector('.orders-header');
            if (ordersHeader) {
                ordersHeader.after(bulkActionBtn);
            }
        }

        bulkActionBtn.innerHTML = `
            <i class="fas fa-check-circle"></i>
            Mark as Delivered (${selectedOrderIds.size})
        `;
        bulkActionBtn.style.display = 'flex';
    } else {
        // Hide button if no orders selected
        if (bulkActionBtn) {
            bulkActionBtn.style.display = 'none';
        }
    }
}

// Mark selected orders as delivered
async function markSelectedAsDelivered() {
    if (selectedOrderIds.size === 0) {
        showToast('No orders selected', 'error');
        return;
    }

    const count = selectedOrderIds.size;
    const confirmation = confirm(`Mark ${count} order${count > 1 ? 's' : ''} as delivered?`);

    if (!confirmation) return;

    try {
        const orderIdsArray = Array.from(selectedOrderIds);
        let successCount = 0;
        let failCount = 0;

        // Show progress
        showToast(`Processing ${count} orders...`, 'info');

        // Update each order
        for (const orderId of orderIdsArray) {
            try {
                const response = await fetch(`/api/admin/orders/${orderId}/status`, {
                    method: 'PUT',
                    headers: {
                        'Content-Type': 'application/json'
                    },
                    body: JSON.stringify({ status: 'delivered' })
                });

                if (response.ok) {
                    successCount++;
                    // Update order in local array
                    const order = allOrders.find(o => o.order_id === orderId);
                    if (order) order.status = 'delivered';
                } else {
                    failCount++;
                }
            } catch (error) {
                console.error(`Failed to update order ${orderId}:`, error);
                failCount++;
            }
        }

        // Clear selection
        selectedOrderIds.clear();

        // Refresh display
        displayOrders(filteredOrders);
        updateOrderStats();

        // Show result
        if (successCount > 0) {
            showToast(`${successCount} order${successCount > 1 ? 's' : ''} marked as delivered!`, 'success');
        }
        if (failCount > 0) {
            showToast(`${failCount} order${failCount > 1 ? 's' : ''} failed to update`, 'error');
        }

    } catch (error) {
        console.error('Bulk update error:', error);
        showToast('Failed to update orders', 'error');
    }
}

// Clear product search
function clearProductSearch() {
    document.getElementById('productSearchInput').value = '';
    document.getElementById('productSearchResults').style.display = 'none';
    document.getElementById('productSearchResults').innerHTML = '';
}

// Close search results when clicking outside
document.addEventListener('click', function (event) {
    const searchInput = document.getElementById('productSearchInput');
    const searchResults = document.getElementById('productSearchResults');

    if (searchInput && searchResults &&
        !searchInput.contains(event.target) &&
        !searchResults.contains(event.target)) {
        searchResults.style.display = 'none';
    }

    const returnSearchInput = document.getElementById('returnProductSearchInput');
    const returnSearchResults = document.getElementById('returnProductSearchResults');

    if (returnSearchInput && returnSearchResults &&
        !returnSearchInput.contains(event.target) &&
        !returnSearchResults.contains(event.target)) {
        returnSearchResults.style.display = 'none';
    }
});
