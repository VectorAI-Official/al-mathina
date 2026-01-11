// Inventory Management JavaScript

let inventoryData = [];
let filteredData = [];

// Load inventory on page load
document.addEventListener('DOMContentLoaded', () => {
    loadInventory();
    loadSections();
    setupEventListeners();
});

// Auto-refresh when page becomes visible (e.g., navigating back from dashboard)
document.addEventListener('visibilitychange', () => {
    if (!document.hidden) {
        console.log('🔄 Page visible - refreshing inventory data...');
        loadInventory();
    }
});

// Setup event listeners
function setupEventListeners() {
    document.getElementById('searchInput').addEventListener('input', filterInventory);
    document.getElementById('sectionFilter').addEventListener('change', filterInventory);
    document.getElementById('stockFilter').addEventListener('change', filterInventory);
    
    document.getElementById('inventoryForm').addEventListener('submit', saveInventory);
    document.getElementById('stockForm').addEventListener('submit', updateStock);
}

// Load all inventory items
async function loadInventory() {
    try {
        const response = await fetch('/admin/api/inventory');
        const data = await response.json();
        
        inventoryData = data.inventory || [];
        filteredData = [...inventoryData];
        
        updateStats();
        renderTable();
    } catch (error) {
        console.error('Error loading inventory:', error);
        showError('Failed to load inventory');
    }
}

// Load sections for filter
async function loadSections() {
    try {
        const response = await fetch('/admin/api/categories/sections');
        const data = await response.json();
        
        const sectionFilter = document.getElementById('sectionFilter');
        const sectionSelect = document.getElementById('section');
        
        data.sections.forEach(section => {
            const option1 = document.createElement('option');
            option1.value = section;
            option1.textContent = section;
            sectionFilter.appendChild(option1);
            
            const option2 = document.createElement('option');
            option2.value = section;
            option2.textContent = section;
            sectionSelect.appendChild(option2);
        });
    } catch (error) {
        console.error('Error loading sections:', error);
    }
}

// Update statistics
function updateStats() {
    const total = inventoryData.length;
    const inStock = inventoryData.filter(item => item.stock_quantity > item.low_stock_threshold).length;
    const lowStock = inventoryData.filter(item => 
        item.stock_quantity > 0 && item.stock_quantity <= item.low_stock_threshold
    ).length;
    const outOfStock = inventoryData.filter(item => item.stock_quantity === 0).length;
    
    document.getElementById('totalItems').textContent = total;
    document.getElementById('inStockItems').textContent = inStock;
    document.getElementById('lowStockItems').textContent = lowStock;
    document.getElementById('outOfStockItems').textContent = outOfStock;
}

// Filter inventory
function filterInventory() {
    const searchTerm = document.getElementById('searchInput').value.toLowerCase();
    const section = document.getElementById('sectionFilter').value;
    const stockLevel = document.getElementById('stockFilter').value;
    
    filteredData = inventoryData.filter(item => {
        // Only search in inventory name, not category
        const matchesSearch = item.inventory_name.toLowerCase().includes(searchTerm);
        const matchesSection = !section || item.section === section;
        
        let matchesStock = true;
        if (stockLevel === 'in_stock') {
            matchesStock = item.stock_quantity > item.low_stock_threshold;
        } else if (stockLevel === 'low_stock') {
            matchesStock = item.stock_quantity > 0 && item.stock_quantity <= item.low_stock_threshold;
        } else if (stockLevel === 'out_of_stock') {
            matchesStock = item.stock_quantity === 0;
        }
        
        return matchesSearch && matchesSection && matchesStock;
    });
    
    renderTable();
}

// Render inventory table
function renderTable() {
    const container = document.getElementById('tableContainer');
    
    if (filteredData.length === 0) {
        container.innerHTML = `
            <div class="empty-state">
                <div class="empty-state-icon">📦</div>
                <h3>No Inventory Items Found</h3>
                <p>Start by adding your first inventory item</p>
            </div>
        `;
        return;
    }
    
    const table = `
        <table class="inventory-table">
            <thead>
                <tr>
                    <th>Item Name</th>
                    <th>Stock</th>
                    <th>Unit</th>
                    <th>Threshold</th>
                    <th>Status</th>
                    <th>Linked Products</th>
                    <th>Actions</th>
                </tr>
            </thead>
            <tbody>
                ${filteredData.map(item => `
                    <tr>
                        <td><strong>${item.inventory_name}</strong></td>
                        <td><strong>${item.stock_quantity}</strong></td>
                        <td>${item.unit || 'N/A'}</td>
                        <td>${item.low_stock_threshold || 10}</td>
                        <td>${getStockBadge(item)}</td>
                        <td>${getLinkBadge(item)}</td>
                        <td>
                            <div class="action-buttons">
                                <button class="btn-icon" onclick="openLinkProductsModal('${item.inventory_id}', '${item.inventory_name}')" title="Link Products" style="background: #e8f5e9; color: #2e7d32;">
                                    🔗
                                </button>
                                <button class="btn-icon btn-stock" onclick="openStockModal('${item.inventory_id}')" title="Update Stock">
                                    📊
                                </button>
                                <button class="btn-icon btn-delete" onclick="deleteInventory('${item.inventory_id}')" title="Delete">
                                    🗑️
                                </button>
                            </div>
                        </td>
                    </tr>
                `).join('')}
            </tbody>
        </table>
    `;
    
    container.innerHTML = table;
}

// Get stock badge HTML
function getStockBadge(item) {
    if (item.stock_quantity === 0) {
        return '<span class="stock-badge stock-out">Out of Stock</span>';
    } else if (item.stock_quantity <= item.low_stock_threshold) {
        return '<span class="stock-badge stock-low">Low Stock</span>';
    } else {
        return '<span class="stock-badge stock-good">In Stock</span>';
    }
}

// Get link status badge HTML
function getLinkBadge(item) {
    const linkedCount = item.linked_products_count || 0;
    
    console.log(`📊 Inventory: ${item.inventory_name}, Linked Count: ${linkedCount}`);
    
    if (linkedCount === 0) {
        return '<span class="link-badge link-none" title="No products linked">⚪ Not Linked</span>';
    } else if (linkedCount === 1) {
        return '<span class="link-badge link-active" title="1 product linked">🟢 1 Product</span>';
    } else {
        return `<span class="link-badge link-active" title="${linkedCount} products linked">🟢 ${linkedCount} Products</span>`;
    }
}

// Open create modal
function openCreateModal() {
    document.getElementById('modalTitle').textContent = 'Add Inventory Item';
    document.getElementById('inventoryForm').reset();
    document.getElementById('inventoryId').value = '';
    document.getElementById('inventoryModal').classList.add('active');
}

// Open edit modal
async function openEditModal(inventoryId) {
    try {
        const response = await fetch(`/admin/api/inventory/${inventoryId}`);
        const data = await response.json();
        const item = data.inventory;
        
        document.getElementById('modalTitle').textContent = 'Edit Inventory Item';
        document.getElementById('inventoryId').value = item.inventory_id;
        document.getElementById('inventoryName').value = item.inventory_name;
        document.getElementById('stockQuantity').value = item.stock_quantity;
        document.getElementById('unit').value = item.unit || '';
        document.getElementById('lowStockThreshold').value = item.low_stock_threshold || 10;
        
        document.getElementById('inventoryModal').classList.add('active');
    } catch (error) {
        console.error('Error loading inventory item:', error);
        showError('Failed to load item details');
    }
}

// Close modal
function closeModal() {
    document.getElementById('inventoryModal').classList.remove('active');
}

// Save inventory (create or update)
async function saveInventory(e) {
    e.preventDefault();
    
    const inventoryId = document.getElementById('inventoryId').value;
    const data = {
        inventory_name: document.getElementById('inventoryName').value,
        stock_quantity: parseInt(document.getElementById('stockQuantity').value),
        unit: document.getElementById('unit').value,
        low_stock_threshold: parseInt(document.getElementById('lowStockThreshold').value) || 10
    };
    
    try {
        let response;
        if (inventoryId) {
            // Update existing
            response = await fetch(`/admin/api/inventory/${inventoryId}`, {
                method: 'PUT',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(data)
            });
        } else {
            // Create new
            response = await fetch('/admin/api/inventory', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(data)
            });
        }
        
        if (response.ok) {
            closeModal();
            loadInventory();
            showSuccess(inventoryId ? 'Inventory updated successfully' : 'Inventory created successfully');
        } else {
            const error = await response.json();
            showError(error.error || 'Failed to save inventory');
        }
    } catch (error) {
        console.error('Error saving inventory:', error);
        showError('Failed to save inventory');
    }
}

// Delete inventory
async function deleteInventory(inventoryId) {
    if (!confirm('Are you sure you want to delete this inventory item? All linked products will be unlinked.')) {
        return;
    }
    
    try {
        const response = await fetch(`/admin/api/inventory/${inventoryId}?force=true`, {
            method: 'DELETE'
        });
        
        if (response.ok) {
            loadInventory();
            showSuccess('Inventory deleted successfully');
        } else {
            const error = await response.json();
            showError(error.error || 'Failed to delete inventory');
        }
    } catch (error) {
        console.error('Error deleting inventory:', error);
        showError('Failed to delete inventory');
    }
}

// Open stock update modal
function openStockModal(inventoryId) {
    const item = inventoryData.find(i => i.inventory_id === inventoryId);
    if (!item) return;
    
    document.getElementById('stockInventoryId').value = item.inventory_id;
    document.getElementById('currentStock').value = item.stock_quantity;
    document.getElementById('stockItemName').textContent = item.inventory_name;
    document.getElementById('stockCurrentValue').textContent = `${item.stock_quantity} ${item.unit}`;
    document.getElementById('quantityChange').value = '';
    document.getElementById('changeType').value = 'add';
    document.getElementById('reason').value = 'restock';
    document.getElementById('changedBy').value = 'admin';
    
    updateQuantityLabel();
    document.getElementById('stockModal').classList.add('active');
}

// Close stock modal
function closeStockModal() {
    document.getElementById('stockModal').classList.remove('active');
}

// Update quantity label based on change type
function updateQuantityLabel() {
    const changeType = document.getElementById('changeType').value;
    const label = document.getElementById('quantityLabel');
    const reasonSelect = document.getElementById('reason');
    
    if (changeType === 'add') {
        label.textContent = 'Quantity to Add';
        reasonSelect.value = 'restock';
    } else {
        label.textContent = 'Quantity to Remove';
        reasonSelect.value = 'damaged';
    }
}

// Update stock
async function updateStock(e) {
    e.preventDefault();
    
    const inventoryId = document.getElementById('stockInventoryId').value;
    const changeType = document.getElementById('changeType').value;
    const quantity = parseInt(document.getElementById('quantityChange').value);
    const reason = document.getElementById('reason').value;
    const changedBy = document.getElementById('changedBy').value;
    
    const data = {
        quantity: changeType === 'add' ? quantity : -quantity,
        reason: reason,
        changed_by: changedBy
    };
    
    try {
        const response = await fetch(`/admin/api/inventory/${inventoryId}/stock`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(data)
        });
        
        if (response.ok) {
            closeStockModal();
            loadInventory();
            showSuccess('Stock updated successfully');
        } else {
            const error = await response.json();
            showError(error.error || 'Failed to update stock');
        }
    } catch (error) {
        console.error('Error updating stock:', error);
        showError('Failed to update stock');
    }
}

// Show success message
function showSuccess(message) {
    alert('✅ ' + message);
}

// Show error message
function showError(message) {
    alert('❌ ' + message);
}

// ========== Link Products Modal Functions ==========

let allProducts = [];
let filteredProducts = [];

// Open link products modal
async function openLinkProductsModal(inventoryId, inventoryName) {
    document.getElementById('linkInventoryId').value = inventoryId;
    document.getElementById('linkInventoryName').textContent = inventoryName;
    document.getElementById('linkProductsModal').classList.add('active');
    
    // Load products
    await loadProductsForLinking(inventoryId, inventoryName);
    
    // Setup search
    document.getElementById('productSearchInput').addEventListener('input', filterProductsList);
}

// Close link products modal
function closeLinkProductsModal() {
    document.getElementById('linkProductsModal').classList.remove('active');
    allProducts = [];
    filteredProducts = [];
}

// Load products for linking
async function loadProductsForLinking(inventoryId, inventoryName) {
    const tbody = document.getElementById('productsLinkList');
    tbody.innerHTML = '<tr><td colspan="4" style="text-align: center; padding: 40px;"><div class="spinner"></div>Loading products...</td></tr>';
    
    try {
        const response = await fetch('/admin/api/products/all');
        const data = await response.json();
        allProducts = data.products || [];
        
        // Filter products that match inventory name (base name matching)
        const baseName = inventoryName.trim();
        filteredProducts = allProducts.filter(p => {
            const productBaseName = p.product_name.replace(/\s*\d+(\.\d+)?\s*(kg|g|ml|l|liters?|pieces?|pcs?|gm|gms|ltr)?\s*$/i, '').trim();
            return productBaseName.toLowerCase().includes(baseName.toLowerCase()) || 
                   baseName.toLowerCase().includes(productBaseName.toLowerCase());
        });
        
        renderProductsList();
    } catch (error) {
        console.error('Error loading products:', error);
        tbody.innerHTML = '<tr><td colspan="4" style="text-align: center; padding: 40px; color: #d32f2f;">❌ Failed to load products</td></tr>';
    }
}

// Filter products list based on search
function filterProductsList() {
    const searchTerm = document.getElementById('productSearchInput').value.toLowerCase();
    const baseName = document.getElementById('linkInventoryName').textContent.toLowerCase();
    
    if (searchTerm) {
        filteredProducts = allProducts.filter(p => 
            p.product_name.toLowerCase().includes(searchTerm) ||
            (p.product_name_tamil && p.product_name_tamil.toLowerCase().includes(searchTerm))
        );
    } else {
        // Reset to base name matching
        filteredProducts = allProducts.filter(p => {
            const productBaseName = p.product_name.replace(/\s*\d+(\.\d+)?\s*(kg|g|ml|l|liters?|pieces?|pcs?|gm|gms|ltr)?\s*$/i, '').trim();
            return productBaseName.toLowerCase().includes(baseName) || 
                   baseName.includes(productBaseName.toLowerCase());
        });
    }
    
    renderProductsList();
}

// Render products list
function renderProductsList() {
    const tbody = document.getElementById('productsLinkList');
    
    if (filteredProducts.length === 0) {
        tbody.innerHTML = '<tr><td colspan="4" style="text-align: center; padding: 40px; color: #666;">No matching products found</td></tr>';
        return;
    }
    
    const currentInventoryId = document.getElementById('linkInventoryId').value;
    console.log('🔍 Current Inventory ID:', currentInventoryId);
    
    tbody.innerHTML = filteredProducts.map(product => {
        const isLinked = product.inventory_id === currentInventoryId;
        console.log(`Product: ${product.product_name}, inventory_id: ${product.inventory_id}, isLinked: ${isLinked}`);
        
        return `
            <tr style="border-bottom: 1px solid #f0f0f0;">
                <td style="padding: 12px;">${product.product_name}</td>
                <td style="padding: 12px;">${product.weight || 'N/A'}</td>
                <td style="padding: 12px; text-align: center;">
                    ${isLinked ? '<span style="padding: 4px 12px; background: #d4edda; color: #155724; border-radius: 12px; font-size: 12px; font-weight: 600;">✓ Linked</span>' : 
                      '<span style="padding: 4px 12px; background: #f8f9fa; color: #666; border-radius: 12px; font-size: 12px;">Not linked</span>'}
                </td>
                <td style="padding: 12px; text-align: center;">
                    ${isLinked ? 
                        `<button onclick="unlinkProduct('${product._id}')" style="padding: 6px 12px; background: #ffebee; color: #c62828; border: none; border-radius: 6px; cursor: pointer; font-size: 12px; font-weight: 600;">🔗 Unlink</button>` :
                        `<button onclick="linkProduct('${product._id}')" style="padding: 6px 12px; background: #e8f5e9; color: #2e7d32; border: none; border-radius: 6px; cursor: pointer; font-size: 12px; font-weight: 600;">🔗 Link</button>`
                    }
                </td>
            </tr>
        `;
    }).join('');
}

// Link product to inventory
async function linkProduct(productId) {
    const inventoryId = document.getElementById('linkInventoryId').value;
    const inventoryName = document.getElementById('linkInventoryName').textContent;
    
    // Confirmation dialog with explanation
    const confirmMessage = `Link this product to "${inventoryName}" inventory?\n\n` +
        `⚠️ IMPORTANT:\n` +
        `• Product's individual stock will remain unchanged\n` +
        `• Inventory stock is managed separately\n` +
        `• When orders are delivered, inventory stock will reduce\n\n` +
        `Continue?`;
    
    if (!confirm(confirmMessage)) {
        return;
    }
    
    try {
        const response = await fetch(`/admin/api/products/${productId}/link-inventory`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ inventory_id: inventoryId })
        });
        
        if (response.ok) {
            showSuccess('✅ Product linked successfully! Product stock remains isolated.');
            // Reload products to update status
            await loadProductsForLinking(inventoryId, inventoryName);
        } else {
            const error = await response.json();
            showError(error.error || 'Failed to link product');
        }
    } catch (error) {
        console.error('Error linking product:', error);
        showError('Failed to link product');
    }
}

// Unlink product from inventory
async function unlinkProduct(productId) {
    const inventoryName = document.getElementById('linkInventoryName').textContent;
    
    // Enhanced confirmation dialog
    const confirmMessage = `⚠️ UNLINK CONFIRMATION\n\n` +
        `Are you sure you want to unlink this product from "${inventoryName}" inventory?\n\n` +
        `After unlinking:\n` +
        `• Product will use its own individual stock\n` +
        `• Centralized inventory tracking will stop\n` +
        `• Product's current stock value remains unchanged\n\n` +
        `Continue with unlinking?`;
    
    if (!confirm(confirmMessage)) {
        return;
    }
    
    try {
        const response = await fetch(`/admin/api/products/${productId}/unlink-inventory`, {
            method: 'POST'
        });
        
        if (response.ok) {
            showSuccess('✅ Product unlinked! Now using individual stock tracking.');
            // Reload products to update status
            const inventoryId = document.getElementById('linkInventoryId').value;
            await loadProductsForLinking(inventoryId, inventoryName);
        } else {
            const error = await response.json();
            showError(error.error || 'Failed to unlink product');
        }
    } catch (error) {
        console.error('Error unlinking product:', error);
        showError('Failed to unlink product');
    }
}
