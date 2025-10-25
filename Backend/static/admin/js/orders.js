/**
 * AL-Madhina Admin - Orders Management
 * Handles order listing, details view, status updates, and invoice printing
 */

// Global state
let allOrders = [];
let currentOrder = null;

// Initialize orders management
document.addEventListener('DOMContentLoaded', function() {
    // Check if we're on the orders page
    if (document.getElementById('ordersContainer')) {
        loadOrders();
        setupEventListeners();
    }
});

// Setup event listeners
function setupEventListeners() {
    // Search and filter
    const searchInput = document.getElementById('orderSearch');
    if (searchInput) {
        searchInput.addEventListener('input', filterOrders);
    }
    
    const statusFilter = document.getElementById('statusFilter');
    if (statusFilter) {
        statusFilter.addEventListener('change', filterOrders);
    }
}

// Load all orders
async function loadOrders() {
    try {
        showLoading('ordersContainer');
        
        const response = await fetch('/api/admin/orders');
        const data = await response.json();
        
        if (data.success) {
            allOrders = data.orders;
            displayOrders(allOrders);
            updateOrderStats();
        } else {
            showError('ordersContainer', 'Failed to load orders');
        }
    } catch (error) {
        console.error('Error loading orders:', error);
        showError('ordersContainer', 'Error loading orders: ' + error.message);
    }
}

// Display orders in list
function displayOrders(orders) {
    const container = document.getElementById('ordersContainer');
    
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
    
    container.innerHTML = orders.map(order => `
        <div class="order-card" onclick="viewOrderDetails('${order.order_id}')">
            <div class="order-card-header">
                <div class="order-info">
                    <h3>Order #${order.order_id}</h3>
                    <p class="order-date">
                        <i class="fas fa-calendar"></i>
                        ${formatDateTime(order.created_at)}
                    </p>
                </div>
                <span class="status-badge status-${order.status}">${order.status.toUpperCase()}</span>
            </div>
            
            <div class="order-card-body">
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
                <span class="payment-method">
                    <i class="fas fa-credit-card"></i>
                    ${order.payment_method || 'COD'}
                </span>
                <span class="view-link">
                    View Details <i class="fas fa-chevron-right"></i>
                </span>
            </div>
        </div>
    `).join('');
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
                    <h3><i class="fas fa-box-open"></i> Order Items</h3>
                    <div class="items-table">
                        <table>
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
                                ${order.items.map(item => `
                                    <tr>
                                        <td><strong>${item.product_name}</strong></td>
                                        <td>${item.weight || '-'}</td>
                                        <td>₹${parseFloat(item.price).toFixed(2)}</td>
                                        <td><strong>×${item.quantity}</strong></td>
                                        <td><strong>₹${(item.price * item.quantity).toFixed(2)}</strong></td>
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
        <div class="order-actions">
            ${order.status === 'pending' ? `
                <button class="btn btn-success" onclick="updateOrderStatus('${order.order_id}', 'delivered')">
                    <i class="fas fa-check-circle"></i> Mark as Delivered
                </button>
                <button class="btn btn-danger" onclick="updateOrderStatus('${order.order_id}', 'cancelled')">
                    <i class="fas fa-times-circle"></i> Cancel Order
                </button>
            ` : `
                <div class="status-info">
                    Order is ${order.status}
                </div>
            `}
            <button class="btn btn-primary" onclick="printInvoice('${order.order_id}')">
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
    
    // Create print window
    const printWindow = window.open('', '_blank');
    
    const invoiceHTML = `
        <!DOCTYPE html>
        <html>
        <head>
            <title>Invoice - Order #${order.order_id}</title>
            <style>
                * { margin: 0; padding: 0; box-sizing: border-box; }
                body {
                    font-family: Arial, sans-serif;
                    padding: 20px;
                    color: #333;
                }
                .invoice-header {
                    text-align: center;
                    margin-bottom: 30px;
                    border-bottom: 3px solid #004D40;
                    padding-bottom: 20px;
                }
                .invoice-header h1 {
                    color: #004D40;
                    font-size: 32px;
                    margin-bottom: 10px;
                }
                .invoice-header p {
                    color: #666;
                    font-size: 14px;
                }
                .invoice-info {
                    display: flex;
                    justify-content: space-between;
                    margin-bottom: 30px;
                }
                .info-block {
                    flex: 1;
                }
                .info-block h3 {
                    color: #004D40;
                    margin-bottom: 10px;
                    font-size: 16px;
                }
                .info-block p {
                    margin: 5px 0;
                    font-size: 14px;
                    line-height: 1.6;
                }
                .invoice-table {
                    width: 100%;
                    border-collapse: collapse;
                    margin: 20px 0;
                }
                .invoice-table th {
                    background: #004D40;
                    color: white;
                    padding: 12px;
                    text-align: left;
                    font-size: 14px;
                }
                .invoice-table td {
                    padding: 10px 12px;
                    border-bottom: 1px solid #ddd;
                    font-size: 14px;
                }
                .invoice-table tr:hover {
                    background: #f5f5f5;
                }
                .invoice-total {
                    text-align: right;
                    margin-top: 20px;
                    font-size: 18px;
                }
                .invoice-total strong {
                    color: #004D40;
                }
                .invoice-footer {
                    margin-top: 50px;
                    text-align: center;
                    color: #666;
                    font-size: 12px;
                    border-top: 2px solid #ddd;
                    padding-top: 20px;
                }
                @media print {
                    body { padding: 0; }
                    .no-print { display: none; }
                }
            </style>
        </head>
        <body>
            <div class="invoice-header">
                <h1>AL-MADHINA</h1>
                <p>INVOICE</p>
            </div>
            
            <div class="invoice-info">
                <div class="info-block">
                    <h3>Bill To:</h3>
                    <p><strong>${order.user_name || 'Customer'}</strong></p>
                    <p>Phone: ${order.user_phone}</p>
                    ${order.user_store_name ? `<p>Store: ${order.user_store_name}</p>` : ''}
                    ${order.user_store_address && (order.user_store_address.street || order.user_store_address.city) ? `
                        <p style="margin-top: 10px;">
                            ${order.user_store_address.street || ''}<br>
                            ${order.user_store_address.city || ''}, ${order.user_store_address.state || ''}<br>
                            ${order.user_store_address.pincode || ''}
                        </p>
                    ` : order.delivery_address && (order.delivery_address.street || order.delivery_address.city) ? `
                        <p style="margin-top: 10px;">
                            ${order.delivery_address.street || ''}<br>
                            ${order.delivery_address.city || ''}, ${order.delivery_address.state || ''}<br>
                            ${order.delivery_address.pincode || ''}
                        </p>
                    ` : ''}
                </div>
                
                <div class="info-block" style="text-align: right;">
                    <h3>Invoice Details:</h3>
                    <p><strong>Order ID:</strong> ${order.order_id}</p>
                    <p><strong>Date:</strong> ${formatDateTime(order.created_at)}</p>
                    <p><strong>Status:</strong> ${order.status.toUpperCase()}</p>
                    <p><strong>Payment:</strong> ${order.payment_method || 'COD'}</p>
                </div>
            </div>
            
            <table class="invoice-table">
                <thead>
                    <tr>
                        <th>#</th>
                        <th>Product Name</th>
                        <th>Weight</th>
                        <th>Price</th>
                        <th>Quantity</th>
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
            
            <div class="invoice-total">
                <p><strong>Grand Total: ₹${parseFloat(order.total_amount).toFixed(2)}</strong></p>
            </div>
            
            <div class="invoice-footer">
                <p>Thank you for your business!</p>
                <p>This is a computer-generated invoice.</p>
            </div>
            
            <script>
                window.onload = function() {
                    window.print();
                    setTimeout(function() {
                        window.close();
                    }, 500);
                };
            </script>
        </body>
        </html>
    `;
    
    printWindow.document.write(invoiceHTML);
    printWindow.document.close();
}

// Filter orders
function filterOrders() {
    const searchTerm = document.getElementById('orderSearch')?.value.toLowerCase() || '';
    const statusFilter = document.getElementById('statusFilter')?.value || 'all';
    
    let filtered = allOrders.filter(order => {
        const matchesSearch = 
            order.order_id.toLowerCase().includes(searchTerm) ||
            (order.user_name && order.user_name.toLowerCase().includes(searchTerm)) ||
            order.user_phone.includes(searchTerm);
        
        const matchesStatus = statusFilter === 'all' || order.status === statusFilter;
        
        return matchesSearch && matchesStatus;
    });
    
    displayOrders(filtered);
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
