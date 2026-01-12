// Inventory Management JavaScript - Server-Side Pagination
// Optimized to prevent browser crashes with large datasets

let inventoryData = []; // Helper for find/edit operations, but strict source is server
let displayedItemsCount = 0;
let currentPage = 1;
const ITEMS_PER_PAGE = 20; // Match server limit default
let isLoading = false;
let hasMore = true;
let inventoryLoadObserver = null;
let currentFilters = {
    search: '',
    section: '',
    stock: '',
    stockStatus: ''
};

// Load inventory on page load
document.addEventListener('DOMContentLoaded', () => {
    loadInventory(true); // Initial load (reset)
    loadSections();
    setupEventListeners();
});

// Auto-refresh when page becomes visible
document.addEventListener('visibilitychange', () => {
    if (!document.hidden) {
        // Optional: Can verify if refetch is needed or just keep current state
        // For pagination, full reload might be jarring, so maybe just refresh current view?
        // Let's reload from scratch to ensure data consistency
        console.log('🔄 Page visible - refreshing inventory data...');
        loadInventory(true);
    }
});

// Setup event listeners
function setupEventListeners() {
    // Debounce search input
    let searchTimeout;
    document.getElementById('searchInput').addEventListener('input', (e) => {
        clearTimeout(searchTimeout);
        searchTimeout = setTimeout(() => {
            currentFilters.search = e.target.value.trim();
            loadInventory(true);
        }, 300); // 300ms debounce
    });

    document.getElementById('sectionFilter').addEventListener('change', (e) => {
        currentFilters.section = e.target.value;
        loadInventory(true);
    });

    document.getElementById('stockFilter').addEventListener('change', (e) => {
        const val = e.target.value;
        currentFilters.stock = val; // Keep for UI state if needed

        // Map UI filter to query params expected by backend
        if (val === 'out_of_stock') {
            currentFilters.stockStatus = 'out_of_stock';
            currentFilters.lowStock = '';
        } else if (val === 'low_stock') {
            currentFilters.stockStatus = '';
            currentFilters.lowStock = 'true';
        } else if (val === 'in_stock') {
            currentFilters.stockStatus = 'in_stock';
            currentFilters.lowStock = '';
        } else {
            currentFilters.stockStatus = '';
            currentFilters.lowStock = '';
        }

        loadInventory(true);
    });

    document.getElementById('inventoryForm').addEventListener('submit', saveInventory);
    document.getElementById('stockForm').addEventListener('submit', updateStock);

    // Unit Change Listener
    const unitSelect = document.getElementById('unit');
    if (unitSelect) {
        unitSelect.addEventListener('change', togglePiecesInput);
    }

    // Calculation Listeners
    document.getElementById('stockQuantity').addEventListener('input', calculateInventoryTotal);
    document.getElementById('piecesPerStock').addEventListener('input', calculateInventoryTotal);
}

// Toggle Pieces Input visibility
function togglePiecesInput() {
    const unit = document.getElementById('unit').value;
    const group = document.getElementById('piecesPerStockGroup');
    const totalDisplay = document.getElementById('totalStockDisplay');

    if (unit === 'pieces') {
        group.style.display = 'block';
        totalDisplay.style.display = 'block';
        calculateInventoryTotal();
    } else {
        group.style.display = 'none';
        totalDisplay.style.display = 'none';
        // Reset multiplier to 1 when hidden to avoid accidental multiplication
        document.getElementById('piecesPerStock').value = 1;
    }
}

// Calculate Total Stock (auto-update the input)
function calculateInventoryTotal() {
    const qty = parseInt(document.getElementById('stockQuantity').value) || 0;
    const perStock = parseInt(document.getElementById('piecesPerStock').value) || 1;
    const total = qty * perStock;
    const input = document.getElementById('totalStockValue');
    if (input) input.value = total;
}

// Load inventory items from server
async function loadInventory(reset = false) {
    if (isLoading) return;

    if (reset) {
        currentPage = 1;
        hasMore = true;
        inventoryData = [];
        displayedItemsCount = 0;

        const tableBody = document.getElementById('inventoryTableBody');
        if (tableBody) {
            tableBody.innerHTML = ''; // Clear table
        }

        // Remove old sentinel if exists
        const oldSentinel = document.getElementById('inventory-load-sentinel');
        if (oldSentinel) oldSentinel.remove();

        // Add loading state
        showTableLoading(true);
    }

    if (!hasMore) return;

    isLoading = true;

    try {
        // Build query URL
        const params = new URLSearchParams({
            page: currentPage,
            limit: ITEMS_PER_PAGE,
            search: currentFilters.search,
            section: currentFilters.section
        });

        if (currentFilters.lowStock) params.append('low_stock', currentFilters.lowStock);
        if (currentFilters.stockStatus) params.append('stock_status', currentFilters.stockStatus);

        console.log(`📡 Fetching inventory page ${currentPage}...`, params.toString());

        const response = await fetch(`/admin/api/inventory?${params.toString()}`);
        const data = await response.json();

        if (reset) {
            showTableLoading(false);
        }

        const newItems = data.inventory || [];

        // Append new items to local cache (for edit/find operations)
        inventoryData = reset ? newItems : [...inventoryData, ...newItems];

        // Render rows
        renderTableRows(newItems);

        // Update pagination state
        const totalPages = data.total_pages || 1;
        hasMore = currentPage < totalPages;

        if (hasMore) {
            currentPage++;
            setupInventoryScrollListener();
        } else {
            // Remove observer if end reached
            if (inventoryLoadObserver) {
                inventoryLoadObserver.disconnect();
                inventoryLoadObserver = null;
            }
            // Remove sentinel
            const sentinel = document.getElementById('inventory-load-sentinel');
            if (sentinel) sentinel.remove();
        }

        updateStats(data.total_count, inventoryData); // Use total_count from server if available

    } catch (error) {
        console.error('Error loading inventory:', error);
        if (reset) {
            showTableError('Failed to load inventory. Please try again.');
        }
    } finally {
        isLoading = false;
    }
}

// Render methods
function showTableLoading(show) {
    const container = document.getElementById('tableContainer');
    const tableBody = document.getElementById('inventoryTableBody');

    if (show) {
        // If table doesn't exist at all, create it with loading spinner
        if (!tableBody) {
            container.innerHTML = `
                <table class="inventory-table">
                    <thead>
                        <tr>
                            <th>Item Name</th>
                            <th>Product Stock</th>
                            <th>Total Inventory</th>
                            <th>Unit</th>
                            <th>Threshold</th>
                            <th>Status</th>
                            <th>Linked Products</th>
                            <th>Actions</th>
                        </tr>
                    </thead>
                    <tbody id="inventoryTableBody">
                        <tr><td colspan="7" style="text-align: center; padding: 40px;"><div class="spinner"></div>Loading...</td></tr>
                    </tbody>
                </table>
            `;
        } else {
            // Table exists, just clear body and show spinner
            tableBody.innerHTML = '<tr><td colspan="7" style="text-align: center; padding: 40px;"><div class="spinner"></div>Loading...</td></tr>';
        }
    } else {
        // Hide loading
        // If table completely missing (shouldn't happen if show=true was called), verify structure
        if (!document.getElementById('inventoryTableBody')) {
            container.innerHTML = `
                <table class="inventory-table">
                    <thead>
                        <tr>
                            <th>Item Name</th>
                            <th>Product Stock</th>
                            <th>Total Inventory</th>
                            <th>Unit</th>
                            <th>Threshold</th>
                            <th>Status</th>
                            <th>Linked Products</th>
                            <th>Actions</th>
                        </tr>
                    </thead>
                    <tbody id="inventoryTableBody">
                    </tbody>
                </table>
            `;
        } else {
            // If table exists and we are stopping loading, 
            // the subsequent 'renderTableRows' will populate it.
            // But if renderTableRows returns early (empty), we need to ensure spinner is gone.
            // We'll leave it to renderTableRows or clear it here.
            // Better to clear it here to be safe.
            const currentBody = document.getElementById('inventoryTableBody');
            // Only clear if it contains the spinner
            if (currentBody.innerHTML.includes('spinner')) {
                currentBody.innerHTML = '';
            }
        }
    }
}

function showTableError(msg) {
    const container = document.getElementById('tableContainer');
    container.innerHTML = `
        <div class="error-state">
            <i class="fas fa-exclamation-triangle"></i>
            <h3>Error</h3>
            <p>${msg}</p>
            <button onclick="loadInventory(true)" class="btn btn-primary">Retry</button>
        </div>
    `;
}

function renderTableRows(items) {
    const tableBody = document.getElementById('inventoryTableBody');
    if (!tableBody) return;

    if (items.length === 0 && currentPage === 1) {
        // Empty state
        const container = document.getElementById('tableContainer');
        container.innerHTML = `
            <div class="empty-state">
                <div class="empty-state-icon">📦</div>
                <h3>No Inventory Items Found</h3>
                <p>Try adjusting your search filters</p>
            </div>
        `;
        return;
    }

    const newRows = items.map(item => `
        <tr>
            <td><strong>${item.inventory_name}</strong></td>
            <td><strong>${item.stock_quantity}</strong></td>
            <td>${item.unit === 'pieces' ? `<strong>${item.total_stock || 0}</strong> (x${item.pieces_per_unit || 1})` : '-'}</td>
            <td>${item.unit || 'N/A'}</td>
            <td>${item.low_stock_threshold || 10}</td>
            <td>${getStockBadge(item)}</td>
            <td>${getLinkBadge(item)}</td>
            <td>
                <div class="action-buttons">
                    <button class="btn-icon" onclick="openLinkProductsModal('${item.inventory_id}', '${item.inventory_name}')" title="Link Products" style="background: #e8f5e9; color: #2e7d32;">
                        🔗
                    </button>
                    <button class="btn-icon btn-edit" onclick="openEditModal('${item.inventory_id}')" title="Edit Item">
                        ✏️
                    </button>
                    <button class="btn-icon btn-delete" onclick="deleteInventory('${item.inventory_id}')" title="Delete">
                        🗑️
                    </button>
                </div>
            </td>
        </tr>
    `).join('');

    // Remove sentinel before appending
    const sentinel = document.getElementById('inventory-load-sentinel');
    if (sentinel) sentinel.remove();

    tableBody.insertAdjacentHTML('beforeend', newRows);
}

// Setup scroll listener using IntersectionObserver
function setupInventoryScrollListener() {
    const tableBody = document.getElementById('inventoryTableBody');
    if (!tableBody) return;

    // Create sentinel if not exists
    let sentinel = document.getElementById('inventory-load-sentinel');
    if (!sentinel) {
        sentinel = document.createElement('tr');
        sentinel.id = 'inventory-load-sentinel';
        sentinel.innerHTML = '<td colspan="7" style="height: 40px; text-align: center; color: #999;"><div class="spinner-small" style="display:inline-block; vertical-align:middle; margin-right:8px;"></div>Loading more items...</td>';
        tableBody.appendChild(sentinel);
    }

    if (inventoryLoadObserver) {
        inventoryLoadObserver.disconnect();
    }

    inventoryLoadObserver = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
            if (entry.isIntersecting && hasMore && !isLoading) {
                console.log('📜 Scroll end reached - loading more...');
                loadInventory(false);
            }
        });
    }, {
        root: null, // viewport
        rootMargin: '200px', // Preload before reaching bottom
        threshold: 0.1
    });

    inventoryLoadObserver.observe(sentinel);
}

// Load sections for filter
async function loadSections() {
    try {
        const response = await fetch('/admin/api/categories/sections');
        const data = await response.json();

        const sectionFilter = document.getElementById('sectionFilter');
        const sectionSelect = document.getElementById('section');

        // Reset
        if (sectionFilter) {
            sectionFilter.innerHTML = '<option value="">All Sections</option>';
        }
        if (sectionSelect) {
            sectionSelect.innerHTML = '<option value="" disabled selected>Select Section</option>';
        }

        data.sections.forEach(section => {
            if (sectionFilter) {
                const option1 = document.createElement('option');
                option1.value = section;
                option1.textContent = section;
                sectionFilter.appendChild(option1);
            }

            if (sectionSelect) {
                const option2 = document.createElement('option');
                option2.value = section;
                option2.textContent = section;
                sectionSelect.appendChild(option2);
            }
        });
    } catch (error) {
        console.error('Error loading sections:', error);
    }
}

// Update statistics
async function updateStats(totalCountFromPagination, currentItems) {
    try {
        // Fetch accurate stats from server
        const response = await fetch('/admin/api/inventory/stats');
        const stats = await response.json();

        document.getElementById('totalItems').textContent = stats.total_items || 0;
        document.getElementById('inStockItems').textContent = stats.in_stock || 0;
        document.getElementById('lowStockItems').textContent = stats.low_stock || 0;
        document.getElementById('outOfStockItems').textContent = stats.out_of_stock || 0;
    } catch (error) {
        console.error('Error loading stats:', error);
        // Fallback
        if (totalCountFromPagination !== undefined) {
            document.getElementById('totalItems').textContent = totalCountFromPagination;
        }
    }
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

    // Reset Pieces UI
    document.getElementById('piecesPerStock').value = 1;
    togglePiecesInput();

    document.getElementById('inventoryModal').classList.add('active');
}

// Open edit modal
function openEditModal(inventoryId) {
    const item = inventoryData.find(i => i.inventory_id === inventoryId);
    if (!item) return;

    document.getElementById('modalTitle').textContent = 'Edit Inventory Item';
    document.getElementById('inventoryId').value = item.inventory_id;
    document.getElementById('inventoryName').value = item.inventory_name;
    document.getElementById('stockQuantity').value = item.stock_quantity;

    // Set dropdowns
    const unitSelect = document.getElementById('unit');
    if (unitSelect) unitSelect.value = item.unit || "";

    const sectionSelect = document.getElementById('section');
    if (sectionSelect) sectionSelect.value = item.section || "";

    document.getElementById('lowStockThreshold').value = item.low_stock_threshold || 10;

    // Pieces UI for Edit
    document.getElementById('piecesPerStock').value = item.pieces_per_unit || 1;
    togglePiecesInput();
    // If pieces unit, load the stored total_stock (editable)
    if (item.unit === 'pieces') {
        const totalInput = document.getElementById('totalStockValue');
        if (totalInput) {
            // Use stored total_stock if exists, otherwise calculate
            totalInput.value = item.total_stock || (item.stock_quantity * (item.pieces_per_unit || 1));
        }
    }

    document.getElementById('inventoryModal').classList.add('active');
}

// Open stock update modal (Keeping for backward compatibility or direct stock adjustments if needed later)
function openStockModal(inventoryId) {
    // We need to fetch latest item details because local pagination cache might be stale
    // or item might not be in loaded set (if we implement search-jump)
    // But since we click *on* a row, it must exist.
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
            loadInventory(true); // Reload to reflect changes
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

// Save inventory (create or update)
async function saveInventory(e) {
    e.preventDefault();

    const inventoryId = document.getElementById('inventoryId').value;

    // Get values
    const stockQty = parseInt(document.getElementById('stockQuantity').value) || 0;
    const unit = document.getElementById('unit').value;

    // Pieces logic
    let piecesPerUnit = 1;
    let totalStock = stockQty; // Default for non-pieces units

    if (unit === 'pieces') {
        piecesPerUnit = parseInt(document.getElementById('piecesPerStock').value) || 1;
        // Read from editable input (may have been manually adjusted)
        totalStock = parseInt(document.getElementById('totalStockValue').value) || 0;
    }

    const data = {
        inventory_name: document.getElementById('inventoryName').value,
        stock_quantity: stockQty,
        pieces_per_unit: piecesPerUnit,
        total_stock: totalStock, // Send the editable total
        unit: unit,
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
            loadInventory(true); // Reset list to show new/updated item
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

// Close modal
function closeModal() {
    document.getElementById('inventoryModal').classList.remove('active');
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
            loadInventory(true);
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

// Show success message
function showSuccess(message) {
    alert('✅ ' + message);
}

// Show error message
function showError(message) {
    alert('❌ ' + message);
}

// ========== Link Products Modal Functions ==========
// Reuse existing link/unlink logic, but ensure they are available globally
// No major changes needed here provided they use IDs correctly.

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

        // INITIALIZE WITH LINKED PRODUCTS
        // Instead of empty, show products already linked to this inventory
        filteredProducts = allProducts.filter(p => p.inventory_id === inventoryId);

        console.log(`Found ${filteredProducts.length} linked products for ${inventoryName}`);

        renderProductsList();
    } catch (error) {
        console.error('Error loading products:', error);
        tbody.innerHTML = '<tr><td colspan="4" style="text-align: center; padding: 40px; color: #d32f2f;">❌ Failed to load products</td></tr>';
    }
}

// Filter products list based on search
function filterProductsList() {
    const searchTerm = document.getElementById('productSearchInput').value.toLowerCase();
    const currentInventoryId = document.getElementById('linkInventoryId').value;

    if (searchTerm) {
        filteredProducts = allProducts.filter(p =>
            p.product_name.toLowerCase().includes(searchTerm) ||
            (p.product_name_tamil && p.product_name_tamil.toLowerCase().includes(searchTerm))
        );
    } else {
        // Reset to ONLY linked products if no search
        filteredProducts = allProducts.filter(p => p.inventory_id === currentInventoryId);
    }

    renderProductsList();
}

// Render products list
function renderProductsList() {
    const tbody = document.getElementById('productsLinkList');

    if (filteredProducts.length === 0) {
        if (document.getElementById('productSearchInput').value === "") {
            tbody.innerHTML = '<tr><td colspan="4" style="text-align: center; padding: 40px; color: #666;">Start typing to search products...</td></tr>';
        } else {
            tbody.innerHTML = '<tr><td colspan="4" style="text-align: center; padding: 40px; color: #666;">No matching products found</td></tr>';
        }
        return;
    }

    const currentInventoryId = document.getElementById('linkInventoryId').value;

    tbody.innerHTML = filteredProducts.map(product => {
        const isLinkedToCurrent = product.inventory_id === currentInventoryId;
        const isLinkedToOther = product.inventory_id && !isLinkedToCurrent;

        let statusBadge, actionButton;

        if (isLinkedToCurrent) {
            statusBadge = '<span style="padding: 4px 12px; background: #d4edda; color: #155724; border-radius: 12px; font-size: 12px; font-weight: 600;">✓ Linked</span>';
            actionButton = `<button onclick="unlinkProduct('${product._id}')" style="padding: 6px 12px; background: #ffebee; color: #c62828; border: none; border-radius: 6px; cursor: pointer; font-size: 12px; font-weight: 600;">🔗 Unlink</button>`;
        } else if (isLinkedToOther) {
            statusBadge = '<span style="padding: 4px 12px; background: #fff3cd; color: #856404; border-radius: 12px; font-size: 12px; font-weight: 600;" title="Linked to another inventory item">⚠️ Linked to Other</span>';
            // Disable linking or show disabled button
            actionButton = `<button disabled style="padding: 6px 12px; background: #f5f5f5; color: #aaa; border: none; border-radius: 6px; cursor: not-allowed; font-size: 12px;">🚫 Linked</button>`;
        } else {
            statusBadge = '<span style="padding: 4px 12px; background: #f8f9fa; color: #666; border-radius: 12px; font-size: 12px;">Not linked</span>';
            actionButton = `<button onclick="linkProduct('${product._id}')" style="padding: 6px 12px; background: #e8f5e9; color: #2e7d32; border: none; border-radius: 6px; cursor: pointer; font-size: 12px; font-weight: 600;">🔗 Link</button>`;
        }

        return `
            <tr style="border-bottom: 1px solid #f0f0f0;">
                <td style="padding: 12px;">${product.product_name}</td>
                <td style="padding: 12px;">${product.weight || 'N/A'}</td>
                <td style="padding: 12px; text-align: center;">${statusBadge}</td>
                <td style="padding: 12px; text-align: center;">${actionButton}</td>
            </tr>
        `;
    }).join('');
}

// Link product to inventory
async function linkProduct(productId) {
    const inventoryId = document.getElementById('linkInventoryId').value;
    const inventoryName = document.getElementById('linkInventoryName').textContent;

    if (!confirm(`Link this product to "${inventoryName}" inventory?`)) return;

    try {
        const response = await fetch(`/admin/api/products/${productId}/link-inventory`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ inventory_id: inventoryId })
        });

        if (response.ok) {
            showSuccess('✅ Product linked successfully!');
            await loadProductsForLinking(inventoryId, inventoryName);
            // Refresh main inventory to update counts (optional, might lose scroll position, skip for now)
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
    const inventoryId = document.getElementById('linkInventoryId').value;

    // Check if this is the last linked product
    // filteredProducts contains the currently displayed list, but we should check 'allProducts' for accuracy
    // count current links for this inventoryId
    const currentLinks = allProducts.filter(p => p.inventory_id === inventoryId);

    if (currentLinks.length <= 1) {
        alert('⚠️ Cannot unlink the only product. An inventory item must have at least one product linked.\n\nSince this inventory item relies on product sales to deduct stock, removing the last link would orphan it.');
        return;
    }

    if (!confirm(`Unlink this product? It will revert to individual stock.`)) return;

    try {
        // Corrected endpoint to match main.go: DELETE /products/:id/link-inventory
        const response = await fetch(`/admin/api/products/${productId}/link-inventory`, {
            method: 'DELETE'
        });

        if (response.ok) {
            showSuccess('✅ Product unlinked!');
            const inventoryName = document.getElementById('linkInventoryName').textContent;

            // Refresh modal list
            await loadProductsForLinking(inventoryId, inventoryName);

            // Auto-refresh the main background table to update counts/status
            // We use 'true' to reset/reload the list to ensure accurate data
            loadInventory(true);
        } else {
            const error = await response.json();
            showError(error.error || 'Failed to unlink product');
        }
    } catch (error) {
        console.error('Error unlinking product:', error);
        showError('Failed to unlink product');
    }
}
