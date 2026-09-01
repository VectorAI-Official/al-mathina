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

    // Wait for content to fully render
    await new Promise(resolve => {
        iframe.onload = () => setTimeout(resolve, 500);
    });

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
  <style>
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
      background: #E8F5E9;
      border: 2px solid #2E7D32;
      border-radius: 8px;
      width: 100%;
      box-sizing: border-box;
    }
    
    .balance-section .balance-row {
      display: flex;
      justify-content: space-between;
      align-items: center;
      font-size: ${shareMode ? '13px' : '15px'};
      padding: 4px 0;
      color: #333333;
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
    <h2 class="balance-section-heading">Balance Summary</h2>
    <div class="balance-section">
      <div class="balance-row">
        <span class="balance-label">Balance Before This Order</span>
        <span class="balance-value">₹${formatInvoiceCurrency(order.balance_before)}</span>
      </div>
      <div class="balance-row">
        <span class="balance-label">This Order Amount</span>
        <span class="balance-value">₹${formatInvoiceCurrency(order.order_amount != null ? order.order_amount : order.total_amount)}</span>
      </div>
      <div class="balance-row grand">
        <span class="balance-label">Total Outstanding</span>
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
