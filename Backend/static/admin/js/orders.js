/**
 * AL-Madhina Admin - Orders Management
 * Handles order listing, details view, status updates, and invoice printing
 */

// Global state
let allOrders = [];
let filteredOrders = []; // Currently filtered/displayed orders
let currentOrder = null;
let selectedDateFilter = {
    type: 'all', // 'all', 'single', 'range'
    singleDate: null,
    startDate: null,
    endDate: null
};

// Initialize orders management
document.addEventListener('DOMContentLoaded', function() {
    console.log('🚀 Orders page initialized');
    
    // Check if we're on the orders page
    if (document.getElementById('ordersContainer')) {
        loadOrders();
        setupEventListeners();
    }
});

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
    document.addEventListener('keydown', function(e) {
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
    console.log('🔄 Loading orders...');
    try {
        showLoading('ordersContainer');
        
        const response = await fetch('/api/admin/orders');
        
        if (!response.ok) {
            throw new Error(`HTTP ${response.status}: ${response.statusText}`);
        }
        
        const data = await response.json();
        console.log(`✅ Loaded ${data.orders?.length || 0} orders`);
        
        if (data.success) {
            allOrders = data.orders;
            filteredOrders = data.orders; // Initialize filtered orders with all orders
            displayOrders(allOrders);
            updateOrderStats();
        } else {
            showError('ordersContainer', 'Failed to load orders');
        }
    } catch (error) {
        console.error('❌ Error loading orders:', error);
        showError('ordersContainer', 'Error loading orders: ' + error.message);
    }
}

// Display orders in list
function displayOrders(orders) {
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
        return;
    }
    
    try {
        container.innerHTML = orders.map(order => `
            <div class="order-card">
                <div class="order-card-header" onclick="viewOrderDetails('${order.order_id}')">
                    <div class="order-info">
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
                            <span><strong>${order.user_name || 'Unknown Customer'}</strong>${order.user_store_name ? ` - <span style="color: #2E7D32; font-weight: 600;">${order.user_store_name}</span>` : ''}</span>
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
        
        console.log(`✅ Displayed ${orders.length} orders`);
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
    const content = document.getElementById('orderDetailsContent');
    
    if (!modal || !content) {
        console.error('Modal elements not found:', { modal: !!modal, content: !!content });
        return;
    }
    
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
    
    modal.style.display = 'block';
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

// Print invoice
function printInvoice(orderId) {
    const order = currentOrder;
    if (!order) return;

    const invoiceHTML = generateInvoiceHTML(order, { printMode: true });

    // Hide the modal to prevent it from being printed
    const modal = document.getElementById('orderDetailsModal');
    const modalWasVisible = modal && modal.style.display !== 'none';
    if (modalWasVisible) {
        modal.style.display = 'none';
    }

    // Small delay to ensure modal is hidden before creating iframe
    setTimeout(() => {
        // Use hidden iframe to avoid popup blockers & stuck preview
        const iframe = document.createElement('iframe');
        iframe.style.position = 'absolute';
        iframe.style.left = '-9999px';
        iframe.style.top = '-9999px';
        iframe.style.width = '0';
        iframe.style.height = '0';
        iframe.style.border = 'none';
        iframe.style.visibility = 'hidden';
        document.body.appendChild(iframe);
        
        const iframeDoc = iframe.contentWindow.document;
        iframeDoc.open();
        iframeDoc.write(invoiceHTML);
        iframeDoc.close();
        
        // Wait for content to load before printing
        iframe.onload = () => {
            setTimeout(() => {
                try {
                    iframe.contentWindow.focus();
                    iframe.contentWindow.print();
                } catch (e) {
                    console.error('Print failed:', e);
                    alert('Print failed. Please try again.');
                }
                
                // Clean up after printing
                setTimeout(() => {
                    if (iframe.parentNode) {
                        document.body.removeChild(iframe);
                    }
                    // Restore modal visibility
                    if (modalWasVisible && modal) {
                        modal.style.display = 'block';
                    }
                }, 1000);
            }, 500);
        };
    }, 100);
}

// Share invoice on WhatsApp (generates PDF)
async function shareInvoiceWhatsApp(orderId) {
    const order = currentOrder;
    if (!order) return;
    
    try {
        console.log('📄 Generating PDF invoice for WhatsApp share...');
        
        const invoiceHTML = generateInvoiceHTML(order, { shareMode: true });
        
        // Create a hidden container with A4 dimensions for rendering
        const container = document.createElement('div');
        container.style.position = 'fixed';
        container.style.left = '-9999px';
        container.style.top = '0';
        container.style.width = '794px'; // A4 width at 96dpi
        container.style.background = '#ffffff';
        document.body.appendChild(container);
        
        container.innerHTML = invoiceHTML;
        
        // Wait for fonts and rendering
        await new Promise(r => setTimeout(r, 1000));
        
        // Capture invoice as canvas with high quality
        const canvas = await html2canvas(container.querySelector('.invoice-container'), {
            scale: 2,
            useCORS: true,
            allowTaint: false,
            backgroundColor: '#ffffff',
            logging: false,
            width: 794,
            windowWidth: 794,
            scrollY: -window.scrollY,
            scrollX: -window.scrollX
        });
        
        // Clean up container
        document.body.removeChild(container);

        // Convert canvas to PDF using jsPDF
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
        
        // Calculate image dimensions to fit A4
        const imgWidth = pdfWidth;
        const imgHeight = (canvas.height * pdfWidth) / canvas.width;
        
        // Add image to PDF
        const imgData = canvas.toDataURL('image/jpeg', 0.95);
        pdf.addImage(imgData, 'JPEG', 0, 0, imgWidth, imgHeight);
        
        // Generate PDF blob
        const pdfBlob = pdf.output('blob');
        const pdfFile = new File([pdfBlob], `Al-Mathina_Invoice_${order.order_id}.pdf`, { type: 'application/pdf' });
        
        console.log('✅ PDF generated successfully:', pdfFile.size, 'bytes');

        // Try to share PDF using Web Share API
        if (navigator.share && navigator.canShare && navigator.canShare({ files: [pdfFile] })) {
            try {
                await navigator.share({
                    title: `Al-Mathina Invoice - Order #${order.order_id}`,
                    text: `Invoice for Order #${order.order_id}\nCustomer: ${order.user_name || 'Customer'}\nTotal: ₹${parseFloat(order.total_amount).toFixed(2)}\n- அல் மதீனா ஏஜென்சீஸ்`,
                    files: [pdfFile]
                });
                console.log('✅ PDF shared successfully via WhatsApp');
                return;
            } catch (err) {
                if (err.name === 'AbortError') {
                    console.log('Share cancelled by user');
                    return;
                }
                console.warn('Web Share API failed:', err);
            }
        }

        // Fallback: Download the PDF file
        console.log('Web Share API not available, downloading PDF...');
        const link = document.createElement('a');
        link.href = URL.createObjectURL(pdfBlob);
        link.download = `Al-Mathina_Invoice_${order.order_id}.pdf`;
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);
        URL.revokeObjectURL(link.href);
        
        alert('Invoice PDF downloaded! You can now share it via WhatsApp.');
    } catch (error) {
        console.error('❌ Error generating PDF for WhatsApp:', error);
        alert('Failed to generate PDF: ' + error.message);
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
    document.querySelectorAll('.action-btn').forEach(btn => { btn.disabled = true; btn.style.opacity='0.5'; btn.style.cursor='not-allowed'; });
    const editBtn = document.querySelector('.btn-edit-items');
    if (editBtn) editBtn.style.display='none';
}

function cancelEditMode() {
    isEditMode = false;
    
    // Reset quantity inputs
    document.querySelectorAll('.qty-input').forEach(input => { input.value = input.dataset.original; input.style.display='none'; });
    document.querySelectorAll('.qty-display').forEach(el => el.style.display='inline');
    
    // Reset price inputs
    document.querySelectorAll('.price-input').forEach(input => { input.value = input.dataset.original; input.style.display='none'; });
    document.querySelectorAll('.price-display').forEach(el => el.style.display='inline');
    
    // Hide add product container
    const addProductContainer = document.getElementById('addProductContainer');
    if (addProductContainer) addProductContainer.style.display = 'none';
    clearProductSearch();
    
    // Hide delete buttons and action column
    document.querySelectorAll('.edit-only-column').forEach(el => el.style.display = 'none');
    document.querySelectorAll('.btn-delete-item').forEach(btn => btn.style.display = 'none');
    
    const saveContainer = document.getElementById('saveButtonContainer');
    if (saveContainer) saveContainer.style.display='none';
    document.querySelectorAll('.action-btn').forEach(btn => { btn.disabled = false; btn.style.opacity='1'; btn.style.cursor='pointer'; });
    const editBtn = document.querySelector('.btn-edit-items');
    if (editBtn) editBtn.style.display='inline-block';
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
async function saveOrderChanges(orderId) {
    if (!confirm('Are you sure you want to save these changes? This will update the order in the database.')) {
        return;
    }
    
    // Collect updated items
    const updatedItems = [];
    let hasChanges = false;
    
    document.querySelectorAll('#orderItemsTable tbody tr').forEach(row => {
        const qtyInput = row.querySelector('.qty-input');
        const priceInput = row.querySelector('.price-input');
        
        const newQuantity = parseInt(qtyInput.value) || 0;
        const originalQuantity = parseInt(qtyInput.dataset.original);
        
        const newPrice = parseFloat(priceInput.value) || 0;
        const originalPrice = parseFloat(priceInput.dataset.original);
        
        if (newQuantity !== originalQuantity || newPrice !== originalPrice) {
            hasChanges = true;
        }
        
        updatedItems.push({
            product_id: row.dataset.productId,
            product_name: row.querySelector('td:first-child strong').textContent,
            weight: row.querySelector('td:nth-child(2)').textContent,
            price: newPrice,
            quantity: newQuantity
        });
    });
    
    if (!hasChanges) {
        alert('No changes were made to the quantities.');
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
            
            // Update current order data
            currentOrder.items = updatedItems;
            currentOrder.total_amount = newTotal;
            
            // Update display spans with new quantities
            document.querySelectorAll('.qty-input').forEach(input => {
                const newQty = input.value;
                input.dataset.original = newQty;
                const display = input.parentElement.querySelector('.qty-display');
                display.textContent = `×${newQty}`;
            });
            
            // Update display spans with new prices
            document.querySelectorAll('.price-input').forEach(input => {
                const newPrice = input.value;
                input.dataset.original = newPrice;
                const display = input.parentElement.querySelector('.price-display');
                display.textContent = `₹${parseFloat(newPrice).toFixed(2)}`;
                
                // Update row data attribute
                const row = input.closest('tr');
                if (row) row.dataset.price = newPrice;
            });
            
            // Exit edit mode
            cancelEditMode();
            
            // Refresh order list
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
    // For share mode, use wider canvas for better content visibility
    const pageWidth = shareMode ? 1000 : 210;
    const pagePadding = shareMode ? 30 : 20;
    
    return `
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width,initial-scale=1.0" />
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
    
    body { 
      font-family: 'Arial', 'Helvetica', sans-serif;
      background: #ffffff;
      color: #000000;
      line-height: 1.6;
      margin: 0;
      padding: 0;
      ${shareMode ? `width: ${pageWidth}px; margin: 0 auto;` : ''}
    }
    
    .invoice-container {
      ${shareMode ? `width: 100%; padding: ${pagePadding}px; box-sizing: border-box;` : 'max-width: 1000px; padding: 40px; box-sizing: border-box;'}
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
      font-size: ${shareMode ? '32px' : '36px'};
      color: #004D40;
      font-weight: 700;
      margin-bottom: 8px;
      letter-spacing: 0.5px;
      white-space: nowrap;
    }
    
    .company-info .subtitle {
      color: #2E7D32;
      font-size: ${shareMode ? '15px' : '16px'};
      font-weight: 600;
      margin-bottom: 8px;
    }
    
    .company-info .phone-numbers {
      color: #000000;
      font-size: ${shareMode ? '14px' : '15px'};
      font-weight: 600;
      margin: 12px 0 8px 0;
    }
    
    .company-info .phone-numbers .emergency-number {
      color: #D32F2F;
      font-weight: 700;
      font-size: ${shareMode ? '15px' : '16px'};
    }
    
    .company-info .address {
      color: #555555;
      font-size: ${shareMode ? '13px' : '14px'};
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
      font-size: ${shareMode ? '16px' : '17px'};
      color: #004D40;
      font-weight: 700;
      margin-bottom: 12px;
      text-transform: uppercase;
      letter-spacing: 0.5px;
    }
    
    .invoice-details p {
      font-size: ${shareMode ? '13px' : '14px'};
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
      font-size: ${shareMode ? '13px' : '14px'};
      font-weight: 700;
      text-align: left;
      padding: 14px 10px;
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
    }
    
    .items-table tbody tr:hover {
      background: #F5F5F5;
    }
    
    .items-table tbody td {
      padding: 12px 10px;
      font-size: ${shareMode ? '13px' : '14px'};
      color: #212121;
      vertical-align: middle;
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
    
    /* Total Section */
    .total-section {
      margin-top: 30px;
      padding: 20px;
      background: #F5F5F5;
      border: 2px solid #004D40;
      border-radius: 8px;
      text-align: right;
      width: 100%;
      box-sizing: border-box;
    }
    
    .total-section .grand-total {
      font-size: ${shareMode ? '24px' : '28px'};
      color: #004D40;
      font-weight: 700;
      letter-spacing: 0.5px;
    }
    
    .total-section .total-label {
      font-size: ${shareMode ? '14px' : '16px'};
      color: #555555;
      margin-right: 15px;
    }
    
    /* Footer */
    .invoice-footer {
      margin-top: 50px;
      padding-top: 25px;
      border-top: 3px solid #E0E0E0;
      text-align: center;
      width: 100%;
    }
    
    .invoice-footer p {
      font-size: ${shareMode ? '12px' : '13px'};
      color: #757575;
      margin: 8px 0;
      line-height: 1.6;
    }
    
    .invoice-footer .thank-you {
      font-size: ${shareMode ? '15px' : '16px'};
      color: #004D40;
      font-weight: 600;
      margin-bottom: 10px;
    }
    
    /* Print Styles */
    @media print {
      body {
        width: 210mm;
        margin: 0;
        padding: 0;
      }
      
      .invoice-container {
        width: 100%;
        max-width: 100%;
        padding: 15mm;
      }
      
      .items-table tbody tr:hover {
        background: transparent;
      }
      
      .invoice-header,
      .invoice-details,
      .items-table thead,
      .items-table tbody tr,
      .total-section,
      .invoice-footer {
        page-break-inside: avoid;
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
        <div class="phone-numbers">7339651541, 8754144759, <span class="emergency-number">8870503350</span></div>
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
    
    <!-- Items Table -->
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
      <span class="total-label">GRAND TOTAL:</span>
      <span class="grand-total">₹${parseFloat(order.total_amount).toFixed(2)}</span>
    </div>
    
    <!-- Footer -->
    <div class="invoice-footer">
      <!-- Footer text removed as per user request -->
    </div>
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
window.onclick = function(event) {
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
    
    resultsContainer.innerHTML = products.map(product => {
        const tamilName = product.product_name_tamil || '';
        const displayName = tamilName ? `${product.product_name} / ${tamilName}` : product.product_name;
        
        return `
            <div class="product-search-item" 
                onclick="addProductToOrder('${product.item_id}', '${product.product_name.replace(/'/g, "\\'")}', '${product.weight || ''}', ${product.price})" 
                style="padding: 12px 16px; border-bottom: 1px solid #e0e0e0; cursor: pointer; display: flex; justify-content: space-between; align-items: center; transition: background 0.2s;" 
                onmouseover="this.style.background='#f5f5f5'" 
                onmouseout="this.style.background='white'">
                <div style="flex: 1;">
                    <div style="margin-bottom: 4px;">
                        <strong style="color: #1B5E20; font-size: 14px;">${product.product_name}</strong>
                        ${tamilName ? `<span style="color: #666; font-size: 13px; margin-left: 6px;">/ ${tamilName}</span>` : ''}
                    </div>
                    <div style="font-size: 12px; color: #666; display: flex; align-items: center; gap: 12px;">
                        <span><i class="fas fa-weight-hanging" style="margin-right: 4px;"></i>${product.weight || 'N/A'}</span>
                        <span><i class="fas fa-rupee-sign" style="margin-right: 4px;"></i>${parseFloat(product.price).toFixed(2)}</span>
                        ${product.section ? `<span style="background: #E8F5E9; padding: 2px 8px; border-radius: 12px; color: #2E7D32; font-size: 11px;">${product.section}</span>` : ''}
                    </div>
                </div>
                <i class="fas fa-plus-circle" style="color: #4CAF50; font-size: 20px;"></i>
            </div>
        `;
    }).join('');
    
    resultsContainer.style.display = 'block';
}

// Add product to order items table
function addProductToOrder(itemId, productName, weight, price) {
    const tbody = document.querySelector('#orderItemsTable tbody');
    
    // Check if product already exists
    const existingRow = Array.from(tbody.querySelectorAll('tr')).find(row => {
        const existingName = row.querySelector('td:first-child strong')?.textContent;
        const existingWeight = row.dataset.weight;
        return existingName === productName && existingWeight === weight;
    });
    
    if (existingRow) {
        // Increment quantity if product already exists
        const qtyInput = existingRow.querySelector('.qty-input');
        if (qtyInput) {
            const currentQty = parseInt(qtyInput.value) || 0;
            qtyInput.value = currentQty + 1;
            qtyInput.dataset.original = qtyInput.value;
            
            // Update display
            const qtyDisplay = existingRow.querySelector('.qty-display');
            if (qtyDisplay) qtyDisplay.textContent = `×${qtyInput.value}`;
            
            // Recalculate totals
            updateItemTotal({ target: qtyInput });
        }
        
        showToast(`Quantity increased for ${productName}`, 'success');
    } else {
        // Add new row
        const newIndex = tbody.children.length;
        const newRow = document.createElement('tr');
        newRow.dataset.itemIndex = newIndex;
        newRow.dataset.productId = itemId;
        newRow.dataset.price = price;
        newRow.dataset.weight = weight;
        
        newRow.innerHTML = `
            <td><strong>${productName}</strong></td>
            <td>${weight || '-'}</td>
            <td class="price-cell">
                <span class="price-display" style="display: none;">₹${parseFloat(price).toFixed(2)}</span>
                <input type="number" class="price-input" value="${price}" min="0" step="0.01" style="display: inline; width: 80px; padding: 4px; text-align: center; border: 2px solid #4CAF50;" data-original="${price}">
            </td>
            <td class="qty-cell">
                <span class="qty-display" style="display: none;">×1</span>
                <input type="number" class="qty-input" value="1" min="1" style="display: inline; width: 60px; padding: 4px; text-align: center; border: 2px solid #4CAF50;" data-original="1">
            </td>
            <td class="item-total"><strong>₹${parseFloat(price).toFixed(2)}</strong></td>
            <td style="display: table-cell;" class="edit-only-column">
                <button class="btn-delete-item" onclick="removeOrderItem(this)" style="display: inline-block; background: #f44336; color: white; border: none; padding: 6px 12px; border-radius: 4px; cursor: pointer;" title="Remove item">
                    <i class="fas fa-trash"></i>
                </button>
            </td>
        `;
        
        tbody.appendChild(newRow);
        
        // Add event listeners to new inputs
        const priceInput = newRow.querySelector('.price-input');
        const qtyInput = newRow.querySelector('.qty-input');
        if (priceInput) priceInput.addEventListener('input', updateItemTotal);
        if (qtyInput) qtyInput.addEventListener('input', updateItemTotal);
        
        showToast(`${productName} added to order`, 'success');
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

// Clear product search
function clearProductSearch() {
    document.getElementById('productSearchInput').value = '';
    document.getElementById('productSearchResults').style.display = 'none';
    document.getElementById('productSearchResults').innerHTML = '';
}

// Close search results when clicking outside
document.addEventListener('click', function(event) {
    const searchInput = document.getElementById('productSearchInput');
    const searchResults = document.getElementById('productSearchResults');
    
    if (searchInput && searchResults && 
        !searchInput.contains(event.target) && 
        !searchResults.contains(event.target)) {
        searchResults.style.display = 'none';
    }
});
