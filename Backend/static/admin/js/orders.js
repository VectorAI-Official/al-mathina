/**
 * AL-Madhina Admin - Orders Management
 * Handles order listing, details view, status updates, and invoice printing
 */

// Global state
let allOrders = [];
let currentOrder = null;

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
                            <span><strong>${order.user_name || 'Unknown Customer'}</strong></span>
                        </div>
                        <div class="info-row">
                            <i class="fas fa-phone"></i>
                            <span>${order.user_phone}</span>
                        </div>
                        ${order.user_store_name ? `
                            <div class="info-row">
                                <i class="fas fa-store"></i>
                                <span>${order.user_store_name}</span>
                            </div>
                        ` : ''}
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
                    <div class="items-table">
                        <table id="orderItemsTable">
                            <thead>
                                <tr>
                                    <th>Product</th>
                                    <th>Weight</th>
                                    <th>Price</th>
                                    <th>Qty</th>
                                    <th>Total</th>
                                </tr>
                            </thead>
                            <tbody>
                                ${order.items.map((item, index) => `
                                    <tr data-item-index="${index}" data-product-id="${item.product_id || ''}" data-price="${item.price}">
                                        <td><strong>${item.product_name}</strong></td>
                                        <td>${item.weight || '-'}</td>
                                        <td>₹${parseFloat(item.price).toFixed(2)}</td>
                                        <td class="qty-cell">
                                            <span class="qty-display">×${item.quantity}</span>
                                            <input type="number" class="qty-input" value="${item.quantity}" min="1" style="display: none;" data-original="${item.quantity}">
                                        </td>
                                        <td class="item-total"><strong>₹${(item.price * item.quantity).toFixed(2)}</strong></td>
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

    // Use hidden iframe to avoid popup blockers & stuck preview
    const iframe = document.createElement('iframe');
    iframe.style.position = 'fixed';
    iframe.style.right = '0';
    iframe.style.bottom = '0';
    iframe.style.width = '0';
    iframe.style.height = '0';
    iframe.style.border = '0';
    document.body.appendChild(iframe);
    iframe.contentDocument.open();
    iframe.contentDocument.write(invoiceHTML);
    iframe.contentDocument.close();
    iframe.onload = () => {
        try {
            iframe.contentWindow.focus();
            iframe.contentWindow.print();
        } catch (e) {
            console.error('Print failed, opening new window fallback:', e);
            const win = window.open('', '_blank');
            win.document.write(invoiceHTML);
            win.document.close();
            win.onload = () => win.print();
        }
        setTimeout(() => document.body.removeChild(iframe), 1500);
    };
}

// Share invoice on WhatsApp
async function shareInvoiceWhatsApp(orderId) {
    const order = currentOrder;
    if (!order) return;
    try {
        const invoiceHTML = generateInvoiceHTML(order, { shareMode: true });
        const w = window.open('', '_blank', 'width=800,height=1000');
        w.document.write(invoiceHTML);
        w.document.close();
        await new Promise(r => setTimeout(r, 800));
        const canvas = await html2canvas(w.document.body, { scale: 2, logging: false, useCORS: true });
        const dataUrl = canvas.toDataURL('image/png');
        w.close();

        const caption = `Invoice - Order #${order.order_id}\nCustomer: ${order.user_name || 'Customer'}\nTotal: ₹${parseFloat(order.total_amount).toFixed(2)}\n- அல் மதீனா ஏஜென்சீஸ்`;

        // Upload to backend to obtain shareable URL
        let uploadedUrl = null;
        try {
            const res = await fetch(`/api/admin/orders/${order.order_id}/invoice-image`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ image_data: dataUrl })
            });
            const json = await res.json();
            if (json.success) uploadedUrl = json.url;
        } catch (e) {
            console.error('Upload failed, falling back to direct sharing:', e);
        }

        const message = uploadedUrl ? `${caption}\nInvoice: ${uploadedUrl}` : caption;

        // Prefer Web Share API if available
        if (navigator.share) {
            try {
                await navigator.share({ title: `Invoice - Order #${order.order_id}`, text: message });
                return;
            } catch (err) {
                if (err.name === 'AbortError') return; // user cancelled
                console.warn('Web Share failed, fallback to WhatsApp link:', err);
            }
        }

        // WhatsApp share link (cannot attach image directly via URL; user will see hosted link)
        const waUrl = `https://wa.me/?text=${encodeURIComponent(message)}`;
        window.open(waUrl, '_blank');
    } catch (error) {
        console.error('Error preparing WhatsApp share:', error);
        alert('Failed to prepare WhatsApp share. Image will download instead.');
        // Fallback: manual image download
        shareInvoiceImageFallbackFromCanvas(orderId);
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
    document.querySelectorAll('.qty-display').forEach(el => el.style.display = 'none');
    document.querySelectorAll('.qty-input').forEach(el => {
        el.style.display = 'inline';
        el.style.width = '60px';
        el.style.padding = '4px';
        el.style.textAlign = 'center';
        el.style.border = '2px solid #4CAF50';
    });
    document.querySelectorAll('.qty-input').forEach(input => input.addEventListener('input', updateItemTotal));
    const saveContainer = document.getElementById('saveButtonContainer');
    if (saveContainer) saveContainer.style.display = 'block';
    document.querySelectorAll('.action-btn').forEach(btn => { btn.disabled = true; btn.style.opacity='0.5'; btn.style.cursor='not-allowed'; });
    const editBtn = document.querySelector('.btn-edit-items');
    if (editBtn) editBtn.style.display='none';
}

function cancelEditMode() {
    isEditMode = false;
    document.querySelectorAll('.qty-input').forEach(input => { input.value = input.dataset.original; input.style.display='none'; });
    document.querySelectorAll('.qty-display').forEach(el => el.style.display='inline');
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
    const price = parseFloat(row.dataset.price);
    const quantity = parseInt(input.value) || 0;
    const itemTotal = price * quantity;
    const totalCell = row.querySelector('.item-total strong');
    if (totalCell) totalCell.textContent = `₹${itemTotal.toFixed(2)}`;
    recalculateGrandTotal();
}

function recalculateGrandTotal() {
    let grandTotal = 0;
    document.querySelectorAll('#orderItemsTable tbody tr').forEach(row => {
        const price = parseFloat(row.dataset.price);
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
        const newQuantity = parseInt(qtyInput.value) || 0;
        const originalQuantity = parseInt(qtyInput.dataset.original);
        
        if (newQuantity !== originalQuantity) {
            hasChanges = true;
        }
        
        updatedItems.push({
            product_id: row.dataset.productId,
            product_name: row.querySelector('td:first-child strong').textContent,
            weight: row.querySelector('td:nth-child(2)').textContent,
            price: parseFloat(row.dataset.price),
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
    // Narrow width when sharing so screenshot fits mobile screen nicely
    const containerMaxWidth = shareMode ? 430 : 860;
    // Base font sizes tuned for readability; slightly smaller for share to reduce wrapping
    const baseFont = shareMode ? 13 : 14;
    const smallFont = shareMode ? 11 : 12;
    const h1Size = shareMode ? 24 : 28;
    const tableHeaderFont = shareMode ? 11 : 12;
    const tableBodyFont = shareMode ? 11 : 12;
    return `
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1" />
  <title>Invoice - Order #${order.order_id}</title>
  <style>
    * { box-sizing: border-box; }
    body { font-family: Arial, sans-serif; margin:0; padding:16px; background:#ffffff; color:#222; }
    .invoice-wrapper { max-width:${containerMaxWidth}px; margin:0 auto; }
    h1 { font-size:${h1Size}px; color:#004D40; margin:0 0 4px 0; }
    .subtitle { color:#2e7d32; font-size:${smallFont}px; font-weight:600; margin-bottom:6px; }
    .invoice-title { color:#004D40; font-size:${baseFont + 1}px; font-weight:700; margin-bottom:8px; }
    .address { color:#555; font-size:${smallFont}px; line-height:1.5; }
    .header { display:flex; gap:12px; justify-content:space-between; align-items:flex-start; border-bottom:3px solid #004D40; padding-bottom:14px; margin-bottom:18px; }
    .header-right p { margin:2px 0; font-size:${smallFont + 1}px; font-weight:600; }
    .emergency { color:#d32f2f; font-weight:700; }
    .info-row { display:flex; flex-wrap:wrap; justify-content:space-between; gap:18px; margin-bottom:18px; }
    .info-block { flex:1 1 220px; min-width:200px; }
    .info-block h3 { font-size:${baseFont}px; color:#004D40; margin:0 0 6px 0; }
    .info-block p { font-size:${smallFont + 1}px; margin:4px 0; line-height:1.4; }
    table { width:100%; border-collapse:collapse; margin-top:4px; }
    thead th { background:#004D40; color:#fff; padding:8px 6px; text-align:left; font-size:${tableHeaderFont}px; }
    tbody td { padding:6px 6px; border-bottom:1px solid #ddd; font-size:${tableBodyFont}px; vertical-align:top; }
    tbody tr:last-child td { border-bottom:2px solid #004D40; }
    .totals { text-align:right; margin-top:14px; font-size:${baseFont + 2}px; font-weight:700; color:#004D40; }
    .footer { margin-top:26px; text-align:center; font-size:${smallFont}px; color:#666; border-top:2px solid #ddd; padding-top:14px; }
    /* Prevent awkward page breaks inside rows when printing */
    @media print { 
      body { padding:0 8px; }
      .invoice-wrapper { max-width:100%; }
      tr, td, th { page-break-inside:avoid; }
      .footer { page-break-inside:avoid; }
    }
  </style>
</head>
<body>
  <div class="invoice-wrapper">
    <div class="header">
      <div class="header-left">
        <h1>அல் மதீனா ஏஜென்சீஸ்</h1>
        <div class="subtitle">மொத்தவிற்பனை மளிகை மற்றும் ஆயில்</div>
        <div class="invoice-title">பில்</div>
        <div class="address">பாரிநகர் 2வது தெரு, அன்னா நகர்,<br/>வடக்கு காட்டூர், திருச்சி - 620019.</div>
      </div>
      <div class="header-right">
        <p>7339051541</p>
        <p>8754144759</p>
        <p>8870503350 <span class="emergency">(அவசரம்)</span></p>
      </div>
    </div>
    <div class="info-row">
      <div class="info-block">
        <h3>Bill To:</h3>
        <p><strong>${order.user_name || 'Customer'}</strong></p>
        <p>Phone: ${order.user_phone}</p>
        ${order.user_store_name ? `<p>Store: ${order.user_store_name}</p>` : ''}
        ${order.user_store_address && (order.user_store_address.street || order.user_store_address.city) ? `
           <p style="margin-top:6px;">
             ${order.user_store_address.street || ''}<br/>
             ${order.user_store_address.city || ''}, ${order.user_store_address.state || ''}<br/>
             ${order.user_store_address.pincode || ''}
           </p>
        ` : order.delivery_address && (order.delivery_address.street || order.delivery_address.city) ? `
           <p style="margin-top:6px;">
             ${order.delivery_address.street || ''}<br/>
             ${order.delivery_address.city || ''}, ${order.delivery_address.state || ''}<br/>
             ${order.delivery_address.pincode || ''}
           </p>
        ` : ''}
      </div>
      <div class="info-block" style="text-align:right;">
        <h3>Invoice Details:</h3>
        <p><strong>Order ID:</strong> ${order.order_id}</p>
        <p><strong>Date:</strong> ${formatDateTime(order.created_at)}</p>
        <p><strong>Payment:</strong> ${order.payment_method || 'COD'}</p>
      </div>
    </div>
    <table>
      <thead>
        <tr>
          <th>#</th><th>Product Name</th><th>Weight</th><th>Price</th><th>Qty</th><th>Total</th>
        </tr>
      </thead>
      <tbody>
        ${order.items.map((item, i) => `
          <tr>
            <td>${i + 1}</td>
            <td>${item.product_name}</td>
            <td>${item.weight || '-'}</td>
            <td>₹${parseFloat(item.price).toFixed(2)}</td>
            <td>${item.quantity}</td>
            <td>₹${(item.price * item.quantity).toFixed(2)}</td>
          </tr>
        `).join('')}
      </tbody>
    </table>
    <div class="totals">Grand Total: ₹${parseFloat(order.total_amount).toFixed(2)}</div>
    <div class="footer">
      <p>Thank you for your business!</p>
      <p>This is a computer-generated invoice.</p>
    </div>
  </div>
  ${printMode ? `<script>window.onload = () => setTimeout(()=> window.print(), 150);</script>` : ''}
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
                
                return matchesSearch && matchesStatus;
            } catch (orderError) {
                console.error(`❌ Error processing order at index ${index}:`, orderError);
                return false;
            }
        });
        
        console.log(`   ✅ Filtered: ${filtered.length} orders match criteria`);
        
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

// Format date and time
function formatDateTime(dateString) {
    if (!dateString) return 'N/A';
    const date = new Date(dateString);
    const options = { 
        year: 'numeric', 
        month: 'short', 
        day: 'numeric',
        hour: '2-digit',
        minute: '2-digit'
    };
    return date.toLocaleDateString('en-US', options);
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
