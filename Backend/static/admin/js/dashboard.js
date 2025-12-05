// Admin Dashboard JavaScript
// Handles CRUD operations, image uploads, and UI interactions

let allProducts = [];
let categoryHierarchy = [];
let categoryMetadata = {}; // Stores category images and metadata
let currentProductId = null;
let deleteProductId = null;

// Lazy loading state for products
let displayedProductsCount = 0;
const PRODUCTS_PER_PAGE = 50;
const PRODUCTS_LOAD_THRESHOLD = 40; // Load more when scrolling to 40th item

// Mobile view state tracking
let mobileViewState = {
    currentView: 'sections', // 'sections', 'main-categories', 'subcategories'
    currentSection: null,
    currentMainCategory: null
};

// Initialize dashboard on page load
document.addEventListener('DOMContentLoaded', function() {
    loadCategories();
    loadProducts();
    setupEventListeners();
});

// Setup event listeners
function setupEventListeners() {
    // Search input
    document.getElementById('searchInput').addEventListener('input', filterProducts);
    
    // Category filter
    document.getElementById('categoryFilter').addEventListener('change', filterProducts);
    
    // Product form submit
    document.getElementById('productForm').addEventListener('submit', handleProductSubmit);
    
    // Note: Image preview removed - using Image Converter instead
    
    // Section dropdown change - enable main category
    document.getElementById('productSection').addEventListener('change', async function(e) {
        const section = e.target.value;
        const mainCategorySelect = document.getElementById('productMainCategory');
        const subCategorySelect = document.getElementById('productSubCategory');
        
        if (section) {
            // Normal section selected - populate main categories
            mainCategorySelect.style.display = 'block';
            subCategorySelect.style.display = 'block';
            
            populateMainCategoryDropdown(section);
        } else {
            // No section selected - reset dropdowns
            mainCategorySelect.style.display = 'block';
            subCategorySelect.style.display = 'block';
            mainCategorySelect.disabled = true;
            mainCategorySelect.innerHTML = '<option value="">Select Section First</option>';
            subCategorySelect.disabled = true;
            subCategorySelect.innerHTML = '<option value="">Select Main Category First</option>';
        }
    });
    
    // Main category dropdown change - enable subcategory
    document.getElementById('productMainCategory').addEventListener('change', function(e) {
        const mainCategory = e.target.value;
        const section = document.getElementById('productSection').value;
        const subCategorySelect = document.getElementById('productSubCategory');
        
        if (mainCategory && section) {
            // Normal main category selected - show dropdown
            subCategorySelect.style.display = 'block';
            populateSubCategoryDropdown(section, mainCategory);
        } else {
            // No main category selected - reset
            subCategorySelect.style.display = 'block';
            subCategorySelect.disabled = true;
            subCategorySelect.innerHTML = '<option value="">Select Main Category First</option>';
        }
    });
    
    // Subcategory dropdown change handler removed - no more "Add New" option
    
    // Close modals on outside click
    window.addEventListener('click', function(event) {
        if (event.target.classList.contains('modal')) {
            event.target.style.display = 'none';
        }
    });
}

// Load categories
async function loadCategories() {
    console.log('%c🚀 STEP 1: loadCategories() STARTED', 'color: #00aa00; font-weight: bold; font-size: 12px;');
    console.trace('📍 Called from:');  // ADD STACK TRACE TO SEE WHO CALLED THIS
    try {
        const timestamp = Date.now();
        console.log('%c📥 Fetching categories from API...', 'color: #0066cc; font-size: 11px;', { timestamp, url: `/admin/api/categories/all?t=${timestamp}` });
        
        const response = await fetch(`/admin/api/categories/all?t=${timestamp}`);
        console.log('%c✅ API Response received', 'color: #00aa00; font-size: 11px;', { status: response.status, statusText: response.statusText });
        
        const data = await response.json();
        console.log('%c📊 Parsed JSON data:', 'color: #0066cc; font-size: 11px;', { hasHierarchy: !!data.hierarchy, hierarchyLength: data.hierarchy?.length });
        
        if (data && data.hierarchy) {
            categoryHierarchy = data.hierarchy;
            console.log('%c✅ categoryHierarchy assigned:', 'color: #00aa00; font-size: 11px;', { totalItems: categoryHierarchy.length });
            
            // Handle empty database case
            if (categoryHierarchy.length === 0) {
                console.warn('%c⚠️  No categories found in database (empty)', 'color: #ff9900; font-size: 11px;');
                categoryHierarchy = [];
            } else {
                console.log('%c📂 Sections found:', 'color: #0066cc; font-size: 11px;', {
                    sections: categoryHierarchy.map(c => c.section).join(', '),
                    totalCategories: categoryHierarchy.length
                });
            }
            
            populateCategoryFilters();
            populateSectionDropdown();
            console.log('%c✅ Dropdowns populated', 'color: #00aa00; font-size: 11px;');
        } else {
            console.error('%c❌ No category hierarchy in API response', 'color: #ff0000; font-size: 11px;', data);
            categoryHierarchy = [];
            populateCategoryFilters();
            populateSectionDropdown();
        }
        
        // Load category metadata (images, etc.)
        console.log('%c🔄 STEP 2: Loading category metadata...', 'color: #00aa00; font-weight: bold; font-size: 12px;');
        await loadCategoryMetadata();
        
        // Restore previous mobile view state or load sections
        console.log('%c🔄 STEP 3: Restoring mobile view state...', 'color: #00aa00; font-weight: bold; font-size: 12px;', mobileViewState);
        if (typeof loadMobileCategorySections === 'function') {
            loadMobileCategorySections();
            
            // Restore the view the user was on before reload
            if (mobileViewState.currentView === 'main-categories' && mobileViewState.currentSection) {
                console.log('%c   🔄 Restoring main category view for:', 'color: #0066cc; font-size: 11px;', mobileViewState.currentSection);
                setTimeout(() => {
                    showMainCategoryCards(mobileViewState.currentSection);
                }, 100);
            } else if (mobileViewState.currentView === 'subcategories' && mobileViewState.currentSection && mobileViewState.currentMainCategory) {
                console.log('%c   🔄 Restoring subcategory view for:', 'color: #0066cc; font-size: 11px;', { 
                    section: mobileViewState.currentSection, 
                    mainCategory: mobileViewState.currentMainCategory 
                });
                setTimeout(() => {
                    showSubCategoryProducts(mobileViewState.currentSection, mobileViewState.currentMainCategory);
                }, 100);
            } else {
                console.log('%c   ✅ Showing default section view', 'color: #00aa00; font-size: 11px;');
            }
        } else {
            console.error('%c❌ loadMobileCategorySections function not found', 'color: #ff0000; font-size: 11px;');
        }
    } catch (error) {
        console.error('%c❌ ERROR in loadCategories():', 'color: #ff0000; font-weight: bold; font-size: 12px;', error);
        console.error('%c   Stack trace:', 'color: #ff0000; font-size: 10px;', error.stack);
        showToast('Failed to load categories. Database may be empty.', 'warning');
        // Initialize with empty array to allow adding
        categoryHierarchy = [];
        populateCategoryFilters();
        populateSectionDropdown();
        
        // Load mobile sections even on error (to show Add button)
        console.log('%c🔄 Loading mobile sections despite error...', 'color: #ff9900; font-size: 11px;');
        if (typeof loadMobileCategorySections === 'function') {
            loadMobileCategorySections();
        }
    }
}

// Load category metadata
async function loadCategoryMetadata() {
    console.log('%c📦 STEP 2B: loadCategoryMetadata() STARTED', 'color: #00aa00; font-weight: bold; font-size: 12px;');
    
    try {
        const timestamp = Date.now();
        console.log('%c1️⃣  Fetching metadata from API...', 'color: #0066cc; font-size: 11px;', { 
            timestamp, 
            url: `/admin/api/categories/metadata?t=${timestamp}` 
        });
        
        const response = await fetch(`/admin/api/categories/metadata?t=${timestamp}`);
        console.log('%c2️⃣  API Response:', 'color: #0066cc; font-size: 11px;', { 
            status: response.status,
            statusText: response.statusText 
        });
        
        const data = await response.json();
        console.log('%c3️⃣  Parsed JSON data:', 'color: #0066cc; font-size: 11px;', { 
            hasMetadata: !!data.metadata,
            metadataLength: data.metadata?.length 
        });
        
        if (data && data.metadata) {
            // Convert array to object for easy lookup
            categoryMetadata = {};
            console.log('%c4️⃣  Processing metadata documents...', 'color: #0066cc; font-weight: bold; font-size: 11px;', {
                totalDocs: data.metadata.length
            });
            
            let sectionCount = 0;
            let mainCatCount = 0;
            let subCatCount = 0;
            let otherCount = 0;
            
            data.metadata.forEach((item, index) => {
                console.log(`   Document ${index + 1}/${data.metadata.length}:`, {
                    type: item.type,
                    section: item.section,
                    name: item.name,
                    name_ta: item.name_ta || '(not set)',
                    image_url: !!item.image_url
                });
                
                // Count by type
                if (item.type === 'section') sectionCount++;
                else if (item.type === 'main_category') mainCatCount++;
                else if (item.type === 'subcategory') subCatCount++;
                else otherCount++;
                
                // Store by section name (for Level 1)
                if (item.type === 'section' && item.section) {
                    categoryMetadata[item.section] = item;
                    console.log(`     ✅ Stored section: ${item.section}`);
                }
                // Store by main category or subcategory name (for Level 2 & 3)
                else if (item.name) {
                    categoryMetadata[item.name] = item;
                    console.log(`     ✅ Stored by name: ${item.name}`);
                }
            });
            
            console.log('%c5️⃣  Metadata processing complete:', 'color: #00aa00; font-weight: bold; font-size: 11px;', {
                sections: sectionCount,
                mainCategories: mainCatCount,
                subcategories: subCatCount,
                others: otherCount,
                totalStored: Object.keys(categoryMetadata).length
            });
            
            console.log('%c6️⃣  Metadata keys stored:', 'color: #0066cc; font-size: 11px;', {
                keys: Object.keys(categoryMetadata).slice(0, 10),
                totalKeys: Object.keys(categoryMetadata).length
            });
            
            console.log('%c✅ loadCategoryMetadata() COMPLETED SUCCESSFULLY', 'color: #00aa00; font-weight: bold; font-size: 12px;');
        } else {
            console.warn('%c❌ No metadata in API response', 'color: #ff9900; font-weight: bold; font-size: 11px;', data);
            categoryMetadata = {};
        }
    } catch (error) {
        console.error('%c❌ ERROR in loadCategoryMetadata():', 'color: #ff0000; font-weight: bold; font-size: 12px;', error);
        console.error('%c   Stack trace:', 'color: #ff0000; font-size: 10px;', error.stack);
        categoryMetadata = {};
    }
}

// Populate category filter for search
function populateCategoryFilters() {
    const categoryFilter = document.getElementById('categoryFilter');
    categoryFilter.innerHTML = '<option value="">All Main Categories</option>';
    
    // Collect all main categories from hierarchy
    const allMainCategories = new Set();
    categoryHierarchy.forEach(item => {
        if (item.main_categories) {
            Object.keys(item.main_categories).forEach(main => allMainCategories.add(main));
        }
    });
    
    Array.from(allMainCategories).sort().forEach(category => {
        const option = document.createElement('option');
        option.value = category;
        option.textContent = category;
        categoryFilter.appendChild(option);
    });
}

// Populate Section dropdown (Level 1)
function populateSectionDropdown() {
    const productSection = document.getElementById('productSection');
    productSection.innerHTML = '<option value="">Select Section</option>';
    
    // Collect sections from both `item.section` and `item.sections` arrays (compat with different hierarchy shapes)
    const sectionsSet = new Set();
    categoryHierarchy.forEach(item => {
        if (!item) return;
        if (item.section && item.section !== null && item.section !== 'undefined') {
            sectionsSet.add(item.section);
        }
        if (Array.isArray(item.sections)) {
            item.sections.forEach(s => {
                if (s && s !== null && s !== 'undefined') sectionsSet.add(s);
            });
        }
    });

    // Convert to sorted array
    const validSections = Array.from(sectionsSet).sort();
    validSections.forEach(sectionName => {
        const option = document.createElement('option');
        option.value = sectionName;
        option.textContent = sectionName;
        productSection.appendChild(option);
    });
    
    // Note: "Add New Section" option removed - users should use mobile view to add sections
}

// Populate Main Category dropdown based on selected section
function populateMainCategoryDropdown(section) {
    const productMainCategory = document.getElementById('productMainCategory');
    productMainCategory.innerHTML = '<option value="">Select Main Category</option>';
    productMainCategory.disabled = false;
    
    // Reset subcategory
    const productSubCategory = document.getElementById('productSubCategory');
    productSubCategory.innerHTML = '<option value="">Select Main Category First</option>';
    productSubCategory.disabled = true;
    
    const sectionData = categoryHierarchy.find(item => item.section === section);
    if (!sectionData || !sectionData.main_categories) {
        return;
    }
    
    // Show actual main categories (Level 2) - matches mobile view structure
    const mainCategories = Object.keys(sectionData.main_categories).sort();
    
    mainCategories.forEach(mainCat => {
        const option = document.createElement('option');
        option.value = mainCat;
        option.textContent = mainCat;
        productMainCategory.appendChild(option);
    });
    
    // Show subcategory field (Level 3)
    productSubCategory.parentElement.style.display = 'block';
    
    // Note: "Add New Main Category" option removed - use Mobile View for category management
}

// Populate Subcategory dropdown based on selected section and main category
function populateSubCategoryDropdown(section, mainCategory) {
    const productSubCategory = document.getElementById('productSubCategory');
    productSubCategory.innerHTML = '<option value="">Select Subcategory</option>';
    productSubCategory.disabled = false;
    
    const sectionData = categoryHierarchy.find(item => item.section === section);
    if (sectionData && sectionData.main_categories && sectionData.main_categories[mainCategory]) {
        sectionData.main_categories[mainCategory].sort().forEach(subCat => {
            const option = document.createElement('option');
            option.value = subCat;
            option.textContent = subCat;
            productSubCategory.appendChild(option);
        });
    }
    
    // Note: "Add New Subcategory" option removed - use Mobile View for category management
}

// Load all products
async function loadProducts() {
    try {
        const timestamp = Date.now();
        const response = await fetch(`/admin/api/products/all?t=${timestamp}`);
        const data = await response.json();
        
        // Handle both response formats
        if (data.products) {
            allProducts = data.products;
            displayProducts(allProducts);
            updateStatistics();
        } else {
            // No products returned
            allProducts = [];
            displayProducts(allProducts);
            updateStatistics();
        }
    } catch (error) {
        console.error('Error loading products:', error);
        showToast('Failed to load products. Database may be empty.', 'warning');
        allProducts = [];
        document.getElementById('productsTableBody').innerHTML = `
            <tr>
                <td colspan="8" style="text-align: center; padding: 40px;">
                    <div style="color: #FF9800; font-size: 48px; margin-bottom: 16px;">📦</div>
                    <div style="color: #757575; font-size: 16px; margin-bottom: 8px;">No products in database</div>
                    <div style="color: #9E9E9E; font-size: 14px;">Add your first product using the "Add Product" button</div>
                </td>
            </tr>
        `;
        updateStatistics();
    }
}

// Display products in table with lazy loading
function displayProducts(products, append = false) {
    const tbody = document.getElementById('productsTableBody');
    
    if (products.length === 0) {
        tbody.innerHTML = `
            <tr>
                <td colspan="8" style="text-align: center; padding: 40px; color: #757575;">
                    📦 No products found
                </td>
            </tr>
        `;
        displayedProductsCount = 0;
        return;
    }
    
    // Reset count if not appending
    if (!append) {
        displayedProductsCount = 0;
        tbody.innerHTML = '';
    }
    
    // Calculate slice range
    const start = displayedProductsCount;
    const end = Math.min(start + PRODUCTS_PER_PAGE, products.length);
    const productsToShow = products.slice(start, end);
    
    // Generate HTML for new products
    const newHTML = productsToShow.map(product => `
        <tr data-product-index="${displayedProductsCount + productsToShow.indexOf(product)}">
            <td>
                ${product.image_url || product.image ? 
                    `<img src="${product.image_url || product.image}" alt="${product.product_name || product.name}" class="product-image">` : 
                    `<div class="product-image-placeholder">📦</div>`
                }
            </td>
            <td>
                <strong>${product.product_name || product.name}</strong><br>
                <small>${product.weight}</small><br>
                <small class="item-id">ID: ${product.item_id || 'N/A'}</small>
            </td>
            <td><span class="category-badge">${product.category_section}</span></td>
            <td><span class="category-badge">${product.category_main}</span></td>
            <td><span class="category-badge">${product.category_sub}</span></td>
            <td><strong>₹${product.price.toFixed(2)}</strong></td>
            <td>${product.stock}</td>
            <td>
                <div class="action-buttons">
                    <button class="action-btn btn-edit" onclick="editProduct('${product._id}')">
                        ✏️ Edit
                    </button>
                    <button class="action-btn btn-delete" onclick="confirmDelete('${product._id}')">
                        🗑️ Delete
                    </button>
                </div>
            </td>
        </tr>
    `).join('');
    
    // Append or replace HTML
    if (append) {
        tbody.insertAdjacentHTML('beforeend', newHTML);
    } else {
        tbody.innerHTML = newHTML;
    }
    
    // Update displayed count
    displayedProductsCount = end;
    
    // Setup scroll listener for lazy loading
    setupProductScrollListener(products);
    
    console.log(`✅ Displayed ${displayedProductsCount}/${products.length} products`);
}

// Setup scroll listener for lazy loading products
let productLoadObserver = null;

function setupProductScrollListener(products) {
    const tbody = document.getElementById('productsTableBody');
    
    // Disconnect existing observer
    if (productLoadObserver) {
        productLoadObserver.disconnect();
    }
    
    // Store current products list
    window.currentProductsList = products;
    
    // Check if we've loaded everything
    if (displayedProductsCount >= products.length) return;
    
    // Create sentinel element at the end
    let sentinel = document.getElementById('product-load-sentinel');
    if (!sentinel) {
        sentinel = document.createElement('tr');
        sentinel.id = 'product-load-sentinel';
        sentinel.innerHTML = '<td colspan="8" style="height: 1px;"></td>';
    }
    tbody.appendChild(sentinel);
    
    // Create IntersectionObserver for smooth lazy loading
    productLoadObserver = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
            if (entry.isIntersecting && displayedProductsCount < products.length) {
                displayProducts(products, true); // Load next batch
            }
        });
    }, {
        root: null,
        rootMargin: '200px', // Start loading 200px before reaching the end
        threshold: 0.1
    });
    
    productLoadObserver.observe(sentinel);
}

// Filter products
function filterProducts() {
    const searchTerm = document.getElementById('searchInput').value.toLowerCase();
    const categoryFilter = document.getElementById('categoryFilter').value;
    
    let filtered = allProducts;
    
    // Apply search filter (now searches across new fields)
    if (searchTerm) {
        filtered = filtered.filter(product => {
            const productName = (product.product_name || product.name || '').toLowerCase();
            const itemId = (product.item_id || '').toLowerCase();
            const section = (product.category_section || '').toLowerCase();
            const mainCat = (product.category_main || '').toLowerCase();
            const subCat = (product.category_sub || '').toLowerCase();
            
            return productName.includes(searchTerm) ||
                   itemId.includes(searchTerm) ||
                   section.includes(searchTerm) ||
                   mainCat.includes(searchTerm) ||
                   subCat.includes(searchTerm);
        });
    }
    
    // Apply category filter (filters by main category)
    if (categoryFilter) {
        filtered = filtered.filter(product => product.category_main === categoryFilter);
    }
    
    displayProducts(filtered);
}

// Update statistics
function updateStatistics() {
    // Handle empty products array
    const totalProducts = allProducts ? allProducts.length : 0;
    document.getElementById('totalProducts').textContent = totalProducts;
    
    // Count unique main categories from products or category hierarchy
    let uniqueCategories = 0;
    if (allProducts && allProducts.length > 0) {
        uniqueCategories = [...new Set(allProducts.map(p => p.category_main).filter(c => c))].length;
    } else if (categoryHierarchy && categoryHierarchy.length > 0) {
        uniqueCategories = [...new Set(categoryHierarchy.map(c => c.main_category).filter(c => c))].length;
    }
    document.getElementById('totalCategories').textContent = uniqueCategories;
    
    // Count low stock products
    const lowStockCount = allProducts ? allProducts.filter(p => p.stock < 20).length : 0;
    document.getElementById('lowStock').textContent = lowStockCount;
}

// Open create product modal
async function openCreateModal() {
    currentProductId = null;
    document.getElementById('modalTitle').textContent = 'Add New Product';
    document.getElementById('productForm').reset();
    document.getElementById('productId').value = '';
    
    // Clear image preview and reset converted file
    const imagePreview = document.getElementById('productImagePreview');
    const previewImg = document.getElementById('productPreviewImg');
    if (imagePreview) imagePreview.style.display = 'none';
    if (previewImg) previewImg.src = '';
    productConvertedFile = null;
    
    // Auto-generate item_id
    const itemIdInput = document.getElementById('productItemId');
    itemIdInput.value = 'Generating...';
    itemIdInput.disabled = true;
    
    try {
        const response = await fetch('/admin/api/generate-item-id');
        const data = await response.json();
        itemIdInput.value = data.item_id;
    } catch (error) {
        console.error('Error generating item ID:', error);
        itemIdInput.value = 'prod_' + Date.now();
    }
    
    // Reset category dropdowns
    const sectionSelect = document.getElementById('productSection');
    const mainCategorySelect = document.getElementById('productMainCategory');
    const subcategorySelect = document.getElementById('productSubCategory');
    
    sectionSelect.style.display = 'block';
    mainCategorySelect.style.display = 'block';
    subcategorySelect.style.display = 'block';
    
    mainCategorySelect.disabled = true;
    mainCategorySelect.innerHTML = '<option value="">Select Section First</option>';
    subcategorySelect.disabled = true;
    subcategorySelect.innerHTML = '<option value="">Select Main Category First</option>';
    
    // Hide all "add new" inputs (section input removed)
    
    document.getElementById('productModal').style.display = 'block';
}

// Open create product modal from mobile view with pre-filled categories
async function openAddProductFromMobile(section, mainCategory, subCategory) {
    currentProductId = null;
    document.getElementById('modalTitle').textContent = 'Add New Product';
    document.getElementById('productForm').reset();
    document.getElementById('productId').value = '';
    
    // Clear image preview and reset converted file
    const imagePreview = document.getElementById('productImagePreview');
    const previewImg = document.getElementById('productPreviewImg');
    if (imagePreview) imagePreview.style.display = 'none';
    if (previewImg) previewImg.src = '';
    productConvertedFile = null;
    
    // Auto-generate item_id
    const itemIdInput = document.getElementById('productItemId');
    itemIdInput.value = 'Generating...';
    itemIdInput.disabled = true;
    
    try {
        const response = await fetch('/admin/api/generate-item-id');
        const data = await response.json();
        itemIdInput.value = data.item_id;
    } catch (error) {
        console.error('Error generating item ID:', error);
        itemIdInput.value = 'prod_' + Date.now();
    }
    
    // Hide all "add new" inputs (section input removed)
    
    // Pre-fill and disable Section dropdown
    const sectionSelect = document.getElementById('productSection');
    sectionSelect.value = section;
    sectionSelect.disabled = true;
    
    console.log('=== OPENING ADD PRODUCT MODAL FROM MOBILE ===');
    console.log('Section:', section);
    console.log('Main Category:', mainCategory);
    console.log('Subcategory:', subCategory);
    
    // Load and pre-fill Main Category dropdown
    populateMainCategoryDropdown(section);
    const mainCategorySelect = document.getElementById('productMainCategory');
    
    // Set value BEFORE disabling
    mainCategorySelect.value = mainCategory;
    console.log('Main Category dropdown value set to:', mainCategorySelect.value);
    console.log('Main Category options:', Array.from(mainCategorySelect.options).map(o => o.value));
    
    // Now disable it
    mainCategorySelect.disabled = true;
    
    // Load and pre-fill Subcategory dropdown
    populateSubCategoryDropdown(section, mainCategory);
    const subCategorySelect = document.getElementById('productSubCategory');
    
    // Set value BEFORE disabling
    subCategorySelect.value = subCategory;
    console.log('Subcategory dropdown value set to:', subCategorySelect.value);
    console.log('Subcategory options:', Array.from(subCategorySelect.options).map(o => o.value));
    
    // Now disable it
    subCategorySelect.disabled = true;
    
    // Store context to refresh mobile view after save
    sessionStorage.setItem('mobileEditContext', JSON.stringify({
        inMobileView: true,
        section: section,
        mainCategory: mainCategory,
        subcategory: subCategory
    }));
    
    document.getElementById('productModal').style.display = 'block';
}

// Edit product
function editProduct(productId) {
    const product = allProducts.find(p => p._id === productId);
    if (!product) {
        showToast('Product not found', 'error');
        return;
    }
    
    currentProductId = productId;
    document.getElementById('modalTitle').textContent = 'Edit Product';
    document.getElementById('productId').value = productId;
    
    // Populate and disable item_id field for editing (read-only)
    const itemIdInput = document.getElementById('productItemId');
    itemIdInput.value = product.item_id || '';
    itemIdInput.disabled = true;
    itemIdInput.placeholder = 'Auto-filled from database';
    
    document.getElementById('productName').value = product.product_name || product.name;
    document.getElementById('productNameTamil').value = product.product_name_ta || '';
    
    // Set section and populate main categories
    const section = product.category_section || '';
    document.getElementById('productSection').value = section;
    if (section) {
        populateMainCategoryDropdown(section);
    }
    
    // Set main category and populate subcategories (proper 3-level structure)
    setTimeout(() => {
        const mainCategory = product.category_main || '';
        const subCategory = product.category_sub || '';
        
        // Set main category (Level 2)
        document.getElementById('productMainCategory').value = mainCategory;
        
        // Populate and set subcategory (Level 3)
        if (mainCategory && section) {
            populateSubCategoryDropdown(section, mainCategory);
            setTimeout(() => {
                document.getElementById('productSubCategory').value = subCategory;
            }, 50);
        }
    }, 50);
    
    document.getElementById('productWeight').value = product.weight;
    document.getElementById('productPrice').value = product.price;
    document.getElementById('productStock').value = product.stock;
    document.getElementById('productDescription').value = product.description || '';
    document.getElementById('productActive').checked = product.active;
    
    // Hide all "add new" inputs and show dropdowns
    const sectionSelect = document.getElementById('productSection');
    const mainCategorySelect = document.getElementById('productMainCategory');
    const subcategorySelect = document.getElementById('productSubCategory');
    
    sectionSelect.style.display = 'block';
    mainCategorySelect.style.display = 'block';
    subcategorySelect.style.display = 'block';
    
    // Show current image if exists
    const imagePreview = document.getElementById('productImagePreview');
    const previewImg = document.getElementById('productPreviewImg');
    
    // Reset converted file
    productConvertedFile = null;
    
    if (product.image_url) {
        if (previewImg) previewImg.src = product.image_url;
        if (imagePreview) imagePreview.style.display = 'block';
    } else {
        if (previewImg) previewImg.src = '';
        if (imagePreview) imagePreview.style.display = 'none';
    }
    
    document.getElementById('productModal').style.display = 'block';
}

// Handle product form submit
async function handleProductSubmit(e) {
    e.preventDefault();
    
    console.log('%c━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', 'color: #ff00ff; font-weight: bold; font-size: 14px;');
    console.log('%c🚀 PRODUCT SUBMIT STARTED', 'color: #ff00ff; font-weight: bold; font-size: 16px; background: #000; padding: 5px;');
    console.log('%c━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', 'color: #ff00ff; font-weight: bold; font-size: 14px;');
    
    const submitButton = document.getElementById('submitButton');
    submitButton.disabled = true;
    submitButton.textContent = 'Saving...';
    
    try {
        console.log('%c📋 STEP 1: Form Elements Check', 'color: #00ffff; font-weight: bold; font-size: 13px; background: #003333; padding: 3px;');
        
        // Temporarily enable disabled fields to get their values (they might be disabled if pre-filled from mobile)
        const sectionSelect = document.getElementById('productSection');
        const mainCategorySelect = document.getElementById('productMainCategory');
        const subcategorySelect = document.getElementById('productSubCategory');
        
        console.log('   🔍 Dropdown Elements:', {
            sectionSelect: !!sectionSelect,
            mainCategorySelect: !!mainCategorySelect,
            subcategorySelect: !!subcategorySelect
        });
        
        console.log('    Dropdown States:', {
            section: {
                value: sectionSelect?.value,
                disabled: sectionSelect?.disabled,
                display: sectionSelect?.style.display
            },
            mainCategory: {
                value: mainCategorySelect?.value,
                disabled: mainCategorySelect?.disabled,
                display: mainCategorySelect?.style.display
            },
            subcategory: {
                value: subcategorySelect?.value,
                disabled: subcategorySelect?.disabled,
                display: subcategorySelect?.style.display
            }
        });
        
        console.log('%c� STEP 2: Enabling Disabled Dropdowns Temporarily', 'color: #00ff00; font-weight: bold; font-size: 13px; background: #003300; padding: 3px;');
        
        const sectionWasDisabled = sectionSelect.disabled;
        const mainWasDisabled = mainCategorySelect.disabled;
        const subWasDisabled = subcategorySelect.disabled;
        
        console.log('   📝 Original Disabled States:', {
            section: sectionWasDisabled,
            mainCategory: mainWasDisabled,
            subcategory: subWasDisabled
        });
        
        sectionSelect.disabled = false;
        mainCategorySelect.disabled = false;
        subcategorySelect.disabled = false;
        
        console.log('   ✅ All dropdowns temporarily enabled');
        
        console.log('%c📝 STEP 4: Reading Category Values', 'color: #ff8800; font-weight: bold; font-size: 13px; background: #332200; padding: 3px;');
        
        // Handle new category creation if needed
        let section = sectionSelect.value;
        let mainCategory = mainCategorySelect.value;
        let subcategory = subcategorySelect.value;
        
        console.log('   📊 Dropdown Values:', {
            section: section,
            mainCategory: mainCategory,
            subcategory: subcategory
        });
        
        console.log('%c🔀 STEP 5: Category Creation Logic', 'color: #ff00ff; font-weight: bold; font-size: 13px; background: #330033; padding: 3px;');
        
        // Section is now always from dropdown - no new section creation
        console.log('   ℹ️ Using existing section:', section);
        console.log('   ℹ️ Using existing main category:', mainCategory);
        console.log('   ℹ️ Using existing subcategory:', subcategory);
        
        // Validate all category values are selected
        if (!section || !mainCategory || !subcategory) {
            console.error('   ❌ ERROR: All categories must be selected!');
            sectionSelect.disabled = sectionWasDisabled;
            mainCategorySelect.disabled = mainWasDisabled;
            subcategorySelect.disabled = subWasDisabled;
            submitButton.disabled = false;
            submitButton.textContent = 'Save Product';
            showToast('Please select all categories', 'error');
            return;
        }
        
        console.log('%c📊 STEP 6: Final Category Values', 'color: #00ff00; font-weight: bold; font-size: 13px; background: #003300; padding: 3px;');
        console.log('   ✅ Section:', section);
        console.log('   ✅ Main Category:', mainCategory);
        console.log('   ✅ Subcategory:', subcategory);
        
        // Restore disabled states after getting values
        sectionSelect.disabled = sectionWasDisabled;
        mainCategorySelect.disabled = mainWasDisabled;
        subcategorySelect.disabled = subWasDisabled;
        
        console.log('%c🖼️ STEP 7: Image Validation', 'color: #ffff00; font-weight: bold; font-size: 13px; background: #333300; padding: 3px;');
        console.log('   📝 currentProductId:', currentProductId);
        console.log('   📝 Is New Product:', !currentProductId);
        
        // ⚠️ MANDATORY IMAGE VALIDATION - Product image is required for new products
        if (!currentProductId) {  // Only validate for new products
            console.log('   🔍 Checking for converted image...');
            console.log('   📝 productConvertedFile:', productConvertedFile);
            
            if (!productConvertedFile) {
                console.error('   ❌ VALIDATION FAILED: Product image is REQUIRED but not selected');
                showToast('❌ Product image is required! Please use Image Converter to select an image.', 'error');
                submitButton.disabled = false;
                submitButton.textContent = 'Save Product';
                return;  // Stop form submission
            }
            console.log('   ✅ Image validation passed:', {
                fileName: productConvertedFile.name,
                fileSize: productConvertedFile.size,
                fileType: productConvertedFile.type
            });
        } else {
            console.log('   ℹ️ Editing existing product - image validation skipped');
        }
        
        console.log('%c📦 STEP 8: Building Product Data Object', 'color: #00ffff; font-weight: bold; font-size: 13px; background: #003333; padding: 3px;');
        
        // Build product data object with proper 3-level structure
        // Section (Level 1 sections) -> Main Category (Level 2) -> Subcategory (Level 3)
        const productData = {
            product_name: document.getElementById('productName').value,
            product_name_ta: document.getElementById('productNameTamil').value || '',
            category_section: section,
            category_main: mainCategory,
            category_sub: subcategory,
            weight: document.getElementById('productWeight').value,
            price: parseFloat(document.getElementById('productPrice').value),
            stock: parseInt(document.getElementById('productStock').value),
            description: document.getElementById('productDescription').value,
            active: document.getElementById('productActive').checked
        };
        
        // Only include item_id for new products (when creating)
        if (!currentProductId) {
            productData.item_id = document.getElementById('productItemId').value;
            console.log('   ✅ item_id added for new product:', productData.item_id);
        } else {
            console.log('   ℹ️ Editing existing product, item_id NOT included');
        }
        
        console.log('%c📤 STEP 9: Product Data Prepared', 'color: #ff00ff; font-weight: bold; font-size: 13px; background: #330033; padding: 3px;');
        console.log('   📝 Current Product ID:', currentProductId);
        console.log('   📝 Operation:', currentProductId ? 'UPDATE' : 'CREATE');
        console.log('   📊 Product Data:', JSON.stringify(productData, null, 2));
        console.log('   ✅ All fields validated');
        
        console.log('%c🌐 STEP 10: Sending API Request', 'color: #ffff00; font-weight: bold; font-size: 13px; background: #333300; padding: 3px;');
        
        // Submit product data
        let response;
        
        if (currentProductId) {
            // Update existing product
            const apiUrl = `/admin/api/products/${currentProductId}`;
            console.log('   🔄 UPDATE existing product');
            console.log('   📍 API URL:', apiUrl);
            console.log('   📝 Method: PUT');
            console.log('   📤 Sending request...');
            
            response = await fetch(apiUrl, {
                method: 'PUT',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify(productData)
            });
        } else {
            // Create new product
            const apiUrl = '/admin/api/products/add';
            console.log('   🆕 CREATE new product');
            console.log('   📍 API URL:', apiUrl);
            console.log('   📝 Method: POST');
            console.log('   📤 Sending request...');
            
            response = await fetch(apiUrl, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify(productData)
            });
        }
        
        console.log('%c📥 STEP 11: API Response Received', 'color: #00ff00; font-weight: bold; font-size: 13px; background: #003300; padding: 3px;');
        console.log('   📊 Response Status:', response.status);
        console.log('   📊 Response OK:', response.ok);
        console.log('   📊 Response Headers:', {
            contentType: response.headers.get('content-type'),
            contentLength: response.headers.get('content-length')
        });
        
        if (!response.ok) {
            console.error('%c❌ STEP 11-ERROR: API Request Failed!', 'color: #ff0000; font-weight: bold; font-size: 14px; background: #330000; padding: 5px;');
            
            const data = await response.json();
            console.error('   📊 Error Response:', JSON.stringify(data, null, 2));
            console.error('   📊 Status Code:', response.status);
            console.error('   📊 Status Text:', response.statusText);
            console.error('   📊 Error Detail:', data.detail);
            
            showToast(data.detail || 'Failed to save product', 'error');
            submitButton.disabled = false;
            submitButton.textContent = 'Save Product';
            return;
        }
        
        const data = await response.json();
        console.log('%c✅ STEP 12: Product Saved Successfully!', 'color: #00ff00; font-weight: bold; font-size: 14px; background: #003300; padding: 5px;');
        console.log('   📊 Success Response:', JSON.stringify(data, null, 2));
        console.log('   📝 Message:', data.message);
        console.log('   📝 Product ID:', data.product?._id);
        console.log('   📝 Product Name:', data.product?.product_name);
        
        // Success - backend returns { message, product }
        showToast(data.message || 'Product saved successfully', 'success');
        
        // IMPORTANT: Get converted image file BEFORE closing modal
        const imageFile = productConvertedFile;
        console.log('=== REQUIRED IMAGE UPLOAD CHECK ===');
        console.log('Product Image (REQUIRED):', imageFile ? imageFile.name : '⚠️ MISSING');
        console.log('Product ID:', data.product ? data.product._id : 'None');
        
        // Now close the modal
        closeModal();
        
        if (imageFile && data.product) {
            const productId = data.product._id;
            console.log('Uploading required product image:', productId);
            
            // Show uploading indicator
            showToast('📤 Uploading product image...', 'info');
            
            await uploadImageFile(productId, imageFile);
            
            console.log('Required image upload completed successfully');
        } else {
            const reason = !imageFile ? '⚠️ Required image not selected' : 'No product ID';
            console.log('WARNING - Image upload skipped:', reason);
            
            // Show warning that required image is missing
            if (!imageFile) {
                showToast('⚠️ Product saved without required image!', 'warning');
            }
        }
        
        // Reload products and categories
        console.log('Reloading products and categories...');
        await loadProducts();
        await loadCategories();
        
        // Check if we need to refresh mobile view
        const mobileContext = sessionStorage.getItem('mobileEditContext');
        if (mobileContext) {
            const context = JSON.parse(mobileContext);
            sessionStorage.removeItem('mobileEditContext');
            
            if (context.inMobileView) {
                // Use the product data from the save response
                const product = data.product;
                
                if (product) {
                    // Refresh the mobile view with the product's category
                    // Use a longer timeout to ensure products are fully loaded
                    setTimeout(() => {
                        loadSectionProducts(
                            product.category_section || context.section, 
                            product.category_sub || context.subcategory
                        );
                    }, 300);
                }
            }
        }
    } catch (error) {
        console.error('Error saving product:', error);
        showToast(`Error saving product: ${error.message || error}`, 'error');
    } finally {
        submitButton.disabled = false;
        submitButton.textContent = 'Save Product';
    }
}

// Note: Old handleImagePreview and clearProductImagePreview functions removed
// Now using Image Converter with productConvertedFile global variable

// Toggle Best Seller status
async function toggleBestSeller(productId, currentStatus) {
    try {
        const newStatus = !currentStatus;
        
        console.log('=== TOGGLING BEST SELLER ===');
        console.log('Product ID:', productId);
        console.log('Current Status:', currentStatus);
        console.log('New Status:', newStatus);
        
        showToast(newStatus ? 'Adding to Best Seller...' : 'Removing from Best Seller...', 'warning');
        
        const response = await fetch(`/admin/api/products/${productId}/best-seller`, {
            method: 'PUT',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({ is_best_seller: newStatus })
        });
        
        if (!response.ok) {
            const data = await response.json();
            console.error('Failed to toggle best seller:', data);
            showToast(data.detail || 'Failed to update Best Seller status', 'error');
            return;
        }
        
        const data = await response.json();
        console.log('Best Seller toggle successful:', data);
        
        showToast(
            newStatus ? '⭐ Product added to Best Seller!' : 'Product removed from Best Seller', 
            'success'
        );
        
        // Reload products to reflect the change
        await loadProducts();
    } catch (error) {
        console.error('Error toggling best seller:', error);
        showToast('Error updating Best Seller status', 'error');
    }
}

// Upload image for product (kept for category image uploads)
function uploadImage(productId) {
    const fileInput = document.createElement('input');
    fileInput.type = 'file';
    fileInput.accept = 'image/jpeg,image/jpg,image/png,image/webp';
    
    fileInput.onchange = async function(e) {
        const file = e.target.files[0];
        if (file) {
            await uploadImageFile(productId, file);
        }
    };
    
    fileInput.click();
}

// Upload image file to local storage
async function uploadImageFile(productId, file) {
    const formData = new FormData();
    formData.append('file', file);
    
    console.log('=== UPLOADING IMAGE FILE ===');
    console.log('Product ID:', productId);
    console.log('File name:', file.name);
    console.log('File size:', file.size);
    console.log('File type:', file.type);
    
    try {
        showToast('Uploading image...', 'warning');
        
        const response = await fetch(`/admin/api/upload/image/${productId}`, {
            method: 'POST',
            body: formData
        });
        
        console.log('Upload response status:', response.status);
        
        if (!response.ok) {
            const data = await response.json();
            console.error('Upload failed:', data);
            showToast(data.detail || 'Failed to upload image', 'error');
            return;
        }
        
        const data = await response.json();
        console.log('Upload successful:', data);
        console.log('Image URL:', data.image_url);
        showToast(data.message || 'Image uploaded successfully!', 'success');
        
        // Reload products to show the new image
        await loadProducts();
    } catch (error) {
        console.error('Error uploading image:', error);
        showToast('Error uploading image', 'error');
    }
}

// Confirm delete
function confirmDelete(productId) {
    deleteProductId = productId;
    document.getElementById('deleteModal').style.display = 'block';
    
    document.getElementById('confirmDeleteButton').onclick = async function() {
        await deleteProduct(productId);
    };
}

// Delete product
async function deleteProduct(productId) {
    try {
        const response = await fetch(`/admin/api/products/${productId}`, {
            method: 'DELETE'
        });
        
        if (!response.ok) {
            const data = await response.json();
            showToast(data.detail || 'Failed to delete product', 'error');
            return;
        }
        
        const data = await response.json();
        showToast(data.message || 'Product deleted successfully', 'success');
        closeDeleteModal();
        await loadProducts();
    } catch (error) {
        console.error('Error deleting product:', error);
        showToast('Error deleting product', 'error');
    }
}

// Close modal
function closeModal() {
    // Re-enable category fields before closing (in case they were disabled from mobile view)
    document.getElementById('productSection').disabled = false;
    document.getElementById('productMainCategory').disabled = false;
    document.getElementById('productSubCategory').disabled = false;
    
    // Reset converted image file
    productConvertedFile = null;
    const imagePreview = document.getElementById('productImagePreview');
    if (imagePreview) imagePreview.style.display = 'none';
    const previewImg = document.getElementById('productPreviewImg');
    if (previewImg) previewImg.src = '';
    
    document.getElementById('productModal').style.display = 'none';
    document.getElementById('productForm').reset();
    currentProductId = null;
}

// Close delete modal
function closeDeleteModal() {
    document.getElementById('deleteModal').style.display = 'none';
    deleteProductId = null;
}

// Show toast notification
function showToast(message, type = 'success') {
    const toast = document.getElementById('toast');
    toast.textContent = message;
    toast.className = `toast ${type} show`;
    
    setTimeout(() => {
        toast.className = 'toast';
    }, 3000);
}

// Create new section
async function createNewSection(section) {
    try {
        const response = await fetch('/admin/api/categories/section', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({ section })
        });
        
        if (!response.ok) {
            const data = await response.json();
            throw new Error(data.detail || 'Failed to create section');
        }
        
        const data = await response.json();
        showToast(data.message || 'Section created successfully', 'success');
    } catch (error) {
        console.error('Error creating section:', error);
        showToast('Failed to create section: ' + error.message, 'error');
        throw error;
    }
}

// Create new main category
async function createNewMainCategory(section, mainCategory) {
    try {
        const response = await fetch('/admin/api/categories/main', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({ section, main_category: mainCategory })
        });
        
        if (!response.ok) {
            const data = await response.json();
            throw new Error(data.detail || 'Failed to create main category');
        }
        
        const data = await response.json();
        showToast(data.message || 'Main category created successfully', 'success');
    } catch (error) {
        console.error('Error creating main category:', error);
        showToast('Failed to create main category: ' + error.message, 'error');
        throw error;
    }
}

// Create new subcategory
async function createNewSubcategory(section, mainCategory, subcategory) {
    try {
        const response = await fetch('/admin/api/categories/sub', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({ section, main_category: mainCategory, subcategory })
        });
        
        if (!response.ok) {
            const data = await response.json();
            throw new Error(data.detail || 'Failed to create subcategory');
        }
        
        const data = await response.json();
        showToast(data.message || 'Subcategory created successfully', 'success');
    } catch (error) {
        console.error('Error creating subcategory:', error);
        showToast('Failed to create subcategory: ' + error.message, 'error');
        throw error;
    }
}

// ============================================
// Mobile Preview Functions
// ============================================

// Navigate to product's original category (from Best Seller)
function navigateToProductCategory(section, mainCategory, subCategory) {
    console.log('Navigating to:', section, '→', mainCategory, '→', subCategory);
    
    // First, go back to show main categories of the section
    showMainCategoryCards(section);
    
    // Then navigate to the subcategory view
    setTimeout(() => {
        showSubCategoryProducts(section, mainCategory);
        
        // Then select the specific subcategory in the sidebar
        setTimeout(() => {
            const sidebarItems = document.querySelectorAll('.mobile-sidebar-item');
            sidebarItems.forEach(item => {
                const itemText = item.querySelector('div:last-child')?.textContent;
                if (itemText === subCategory) {
                    selectSubCategory(section, mainCategory, subCategory, item);
                }
            });
        }, 100);
    }, 100);
}

// Open mobile preview panel
async function openMobileView() {
    const panel = document.getElementById('mobilePreviewPanel');
    const backdrop = document.getElementById('mobilePreviewBackdrop');
    panel.classList.add('active');
    backdrop.classList.add('active');
    
    // CRITICAL FIX: Reset container visibility states to default
    const categoriesContainer = document.getElementById('mobileCategorySections');
    const productsContainer = document.getElementById('mobileProductsList');
    
    if (categoriesContainer) {
        categoriesContainer.style.display = 'block';  // Show categories by default
    }
    if (productsContainer) {
        productsContainer.style.display = 'none';  // Hide products by default
    }
    
    // Show loading state
    const container = document.getElementById('mobileCategorySections');
    container.innerHTML = `
        <div class="mobile-empty-state">
            <div class="icon">⏳</div>
            <div class="message">Loading categories...</div>
        </div>
    `;
    
    // Ensure data is loaded before showing mobile view
    if (!categoryHierarchy || categoryHierarchy.length === 0 || !allProducts || allProducts.length === 0) {
        await Promise.all([loadCategories(), loadProducts()]);
    }
    
    // Now load the mobile preview
    loadMobilePreview();
}

// Close mobile preview panel
function closeMobileView() {
    const panel = document.getElementById('mobilePreviewPanel');
    const backdrop = document.getElementById('mobilePreviewBackdrop');
    panel.classList.remove('active');
    backdrop.classList.remove('active');
    
    // IMPORTANT: Re-enable category fields in case they were disabled from mobile add
    // This ensures "Add New Product" from dashboard works correctly after closing mobile view
    const sectionSelect = document.getElementById('productSection');
    const mainCategorySelect = document.getElementById('productMainCategory');
    const subcategorySelect = document.getElementById('productSubCategory');
    
    if (sectionSelect) sectionSelect.disabled = false;
    if (mainCategorySelect) mainCategorySelect.disabled = false;
    if (subcategorySelect) subcategorySelect.disabled = false;
}

// Load mobile preview content
function loadMobilePreview() {
    loadMobileCategorySections();
    loadMobileProducts();
}

// Load category sections for mobile view
function loadMobileCategorySections() {
    console.log('%c📱 MOBILE VIEW: loadMobileCategorySections() STARTED', 'color: #0066cc; font-weight: bold; font-size: 13px;');
    
    // Only reset state if we're explicitly loading sections (not restoring a previous view)
    const isExplicitSectionLoad = !mobileViewState.currentSection;
    if (isExplicitSectionLoad) {
        mobileViewState.currentView = 'sections';
        mobileViewState.currentSection = null;
        mobileViewState.currentMainCategory = null;
    }
    
    const container = document.getElementById('mobileCategorySections');
    console.log('%c1️⃣  Container check:', 'color: #0066cc; font-weight: bold; font-size: 11px;', {
        elementFound: !!container,
        elementId: 'mobileCategorySections',
        innerHTML_length: container?.innerHTML?.length || 0
    });
    
    if (!container) {
        console.error('%c❌ CRITICAL: Container #mobileCategorySections not found in DOM!', 'color: #ff0000; font-weight: bold; font-size: 11px;');
        return;
    }
    
    console.log('%c2️⃣  Data validation:', 'color: #0066cc; font-weight: bold; font-size: 11px;', {
        categoryHierarchy_defined: typeof categoryHierarchy !== 'undefined',
        categoryHierarchy_length: categoryHierarchy?.length,
        categoryHierarchy_isArray: Array.isArray(categoryHierarchy)
    });
    
    if (!categoryHierarchy || !Array.isArray(categoryHierarchy)) {
        console.error('%c❌ CRITICAL: categoryHierarchy is not an array!', 'color: #ff0000; font-weight: bold; font-size: 11px;', categoryHierarchy);
        return;
    }
    
    if (categoryHierarchy.length === 0) {
        console.warn('%c⚠️  WARNING: categoryHierarchy is empty (no categories in database)', 'color: #ff9900; font-weight: bold; font-size: 11px;');
    }
    
    let html = '<div class="mobile-category-title">📂 Sections</div>';
    
    // Always show search container if there are categories
    if (categoryHierarchy && categoryHierarchy.length > 0) {
        console.log('%c3️⃣  Adding search container...', 'color: #0066cc; font-size: 11px;');
        html += `
            <div class="mobile-search-container">
                <input type="text" 
                       id="mobileSearchInput" 
                       class="mobile-search-input" 
                       placeholder="🔍 Search categories..."
                       oninput="filterMobileCategories(this.value)">
                <button class="mobile-search-clear" onclick="clearMobileSearch()" style="display: none;">✕</button>
            </div>
        `;
    }
    
    html += '<div class="mobile-category-grid" id="mobileCategoryGrid">';
    
    console.log('%c4️⃣  Extracting sections from hierarchy...', 'color: #0066cc; font-weight: bold; font-size: 11px;');
    
    // Get unique sections from category hierarchy (support `section` and `sections` array shapes)
    if (categoryHierarchy && categoryHierarchy.length > 0) {
        const sectionsSet = new Set();
        let sectionCount = 0;
        
        categoryHierarchy.forEach((item, index) => {
            if (!item) {
                console.warn(`   ⚠️  Item at index ${index} is null/undefined`, item);
                return;
            }
            
            if (item.section && item.section !== null && item.section !== 'undefined') {
                console.log(`   Adding from item.section: "${item.section}"`);
                sectionsSet.add(item.section);
                sectionCount++;
            }
            
            if (Array.isArray(item.sections)) {
                console.log(`   Found item.sections array:`, item.sections);
                item.sections.forEach(s => {
                    if (s && s !== null && s !== 'undefined') {
                        console.log(`   Adding from item.sections array: "${s}"`);
                        sectionsSet.add(s);
                        sectionCount++;
                    }
                });
            }
        });

        const sections = Array.from(sectionsSet).sort();
        console.log('%c   ✅ Sections extracted:', 'color: #00aa00; font-size: 11px;', {
            totalSections: sections.length,
            sectionNames: sections,
            categoriesProcessed: categoryHierarchy.length
        });

        if (sections.length === 0) {
            console.warn('%c   ⚠️  No sections found in categoryHierarchy!', 'color: #ff9900; font-size: 11px;');
        }

        sections.forEach((section, idx) => {
            console.log(`   📌 Section ${idx + 1}/${sections.length}: "${section}"`);
            html += `
                <div class="mobile-category-card" data-category-name="${section.toLowerCase()}" onclick="showMobileCategoryProducts('${section.replace(/'/g, "\\'")}')">
                    <button class="edit-category-btn" onclick="openEditSectionModal('${section.replace(/'/g, "\\'")}', event)" title="Edit Section">
                        ✏️
                    </button>
                    <button class="delete-category-btn" onclick="confirmDeleteSection('${section.replace(/'/g, "\\'")}', event)" title="Delete Section">
                        🗑️
                    </button>
                    <div class="name">${section}</div>
                </div>
            `;
        });
    } else {
        console.warn('%c   ⚠️  No categories to extract sections from', 'color: #ff9900; font-size: 11px;');
        // Show empty state message when no categories exist
        html += `
            <div class="mobile-empty-state-inline">
                <div class="icon">📂</div>
                <div class="message">No sections yet. Click "Add Section" to get started!</div>
            </div>
        `;
    }
    
    // Always show "Add Section" button
    console.log('%c5️⃣  Adding "Add Section" button...', 'color: #0066cc; font-size: 11px;');
    html += `
        <div class="mobile-category-card mobile-add-category-card" data-category-name="add new" onclick="openAddCategoryModal()">
            <div class="name">➕ Add Section</div>
        </div>
    `;
    
    html += '</div>';
    
    console.log('%c6️⃣  HTML generation complete:', 'color: #0066cc; font-weight: bold; font-size: 11px;', {
        totalCharacters: html.length,
        htmlPreview: html.substring(0, 100) + '...'
    });
    
    console.log('%c7️⃣  Setting innerHTML on container...', 'color: #0066cc; font-size: 11px;');
    try {
        container.innerHTML = html;
        console.log('%c   ✅ innerHTML set successfully', 'color: #00aa00; font-size: 11px;');
        
        // Verify rendering
        const renderedCards = container.querySelectorAll('.mobile-category-card');
        console.log('%c8️⃣  Verification - Cards rendered:', 'color: #0066cc; font-weight: bold; font-size: 11px;', {
            totalCards: renderedCards.length,
            expectedCards: categoryHierarchy.length + 1 // +1 for Add Section
        });
        
        if (renderedCards.length === 0 && categoryHierarchy.length > 0) {
            console.error('%c   ❌ ERROR: No cards found but categories exist!', 'color: #ff0000; font-weight: bold; font-size: 11px;');
        }
    } catch (renderError) {
        console.error('%c   ❌ CRITICAL ERROR setting innerHTML:', 'color: #ff0000; font-weight: bold; font-size: 11px;', renderError);
        return;
    }
    
    // Hide products section initially
    const productsContainer = document.getElementById('mobileProductsList');
    if (productsContainer) {
        productsContainer.style.display = 'none';
        console.log('%c9️⃣  Products container hidden (display: none)', 'color: #0066cc; font-size: 11px;');
    } else {
        console.warn('%c   ⚠️  Products container #mobileProductsList not found', 'color: #ff9900; font-size: 11px;');
    }
    
    console.log('%c✅ loadMobileCategorySections() COMPLETED SUCCESSFULLY', 'color: #00aa00; font-weight: bold; font-size: 13px;');
}

// Filter mobile categories based on search input
function filterMobileCategories(searchTerm) {
    const searchInput = document.getElementById('mobileSearchInput');
    const clearButton = document.querySelector('.mobile-search-clear');
    const categoryCards = document.querySelectorAll('.mobile-category-card');
    const searchLower = searchTerm.toLowerCase().trim();
    
    // Show/hide clear button
    if (searchTerm.length > 0) {
        clearButton.style.display = 'block';
    } else {
        clearButton.style.display = 'none';
    }
    
    let visibleCount = 0;
    
    // Filter categories
    categoryCards.forEach(card => {
        const categoryName = card.getAttribute('data-category-name');
        if (categoryName.includes(searchLower)) {
            card.style.display = 'block';
            visibleCount++;
        } else {
            card.style.display = 'none';
        }
    });
    
    // Show "no results" message if no categories match
    const grid = document.getElementById('mobileCategoryGrid');
    let noResultsMsg = document.getElementById('mobileNoResults');
    
    if (visibleCount === 0 && searchTerm.length > 0) {
        if (!noResultsMsg) {
            noResultsMsg = document.createElement('div');
            noResultsMsg.id = 'mobileNoResults';
            noResultsMsg.className = 'mobile-no-results';
            noResultsMsg.innerHTML = `
                <div class="icon">🔍</div>
                <p>No categories found for "${searchTerm}"</p>
            `;
            grid.appendChild(noResultsMsg);
        } else {
            noResultsMsg.querySelector('p').textContent = `No categories found for "${searchTerm}"`;
            noResultsMsg.style.display = 'block';
        }
    } else if (noResultsMsg) {
        noResultsMsg.style.display = 'none';
    }
}

// Clear mobile search
function clearMobileSearch() {
    const searchInput = document.getElementById('mobileSearchInput');
    searchInput.value = '';
    filterMobileCategories('');
    searchInput.focus();
}

// Show products for a selected category
function showMobileCategoryProducts(categorySection) {
    console.log('%c📱 MOBILE VIEW: showMobileCategoryProducts() STARTED', 'color: #0066cc; font-weight: bold; font-size: 13px;');
    console.log('%c   Selected section:', 'color: #0066cc; font-size: 11px;', { section: categorySection });
    
    const categoriesContainer = document.getElementById('mobileCategorySections');
    const productsContainer = document.getElementById('mobileProductsList');
    
    console.log('%c1️⃣  Container validation:', 'color: #0066cc; font-weight: bold; font-size: 11px;', {
        sectionsContainer_found: !!categoriesContainer,
        productsContainer_found: !!productsContainer
    });
    
    if (!categoriesContainer || !productsContainer) {
        console.error('%c❌ CRITICAL: One or both containers not found!', 'color: #ff0000; font-weight: bold; font-size: 11px;', {
            sectionsContainer: !!categoriesContainer,
            productsContainer: !!productsContainer
        });
        return;
    }
    
    console.log('%c2️⃣  Toggling container visibility...', 'color: #0066cc; font-size: 11px;');
    try {
        categoriesContainer.style.display = 'none';
        console.log('   ✅ Sections hidden (display: none)');
        
        productsContainer.style.display = 'block';
        console.log('   ✅ Products shown (display: block)');
    } catch (e) {
        console.error('%c   ❌ ERROR toggling display:', 'color: #ff0000; font-size: 11px;', e);
        return;
    }
    
    // SPECIAL HANDLING: Best Seller shows featured products directly
    console.log('%c3️⃣  Checking section type...', 'color: #0066cc; font-weight: bold; font-size: 11px;');
    if (categorySection === 'Best Seller') {
        console.log('%c   🌟 Best Seller section detected - showing featured products', 'color: #ff9900; font-size: 11px;');
        showBestSellerProducts();
    } else {
        console.log(`%c   📂 Normal section detected - showing main categories for: "${categorySection}"`, 'color: #0066cc; font-size: 11px;');
        // Normal sections: Show main category cards (Level 2)
        showMainCategoryCards(categorySection);
    }
    
    console.log('%c✅ showMobileCategoryProducts() COMPLETED', 'color: #00aa00; font-weight: bold; font-size: 13px;');
}

// Show Best Seller products directly (no main categories)
function showBestSellerProducts() {
    const productsContainer = document.getElementById('mobileProductsList');
    
    // Filter products where is_best_seller = true
    const bestSellerProducts = allProducts.filter(product => product.is_best_seller === true);
    
    console.log('=== BEST SELLER SECTION ===');
    console.log('Featured products:', bestSellerProducts.length);
    
    let html = `
        <div class="mobile-back-button" onclick="showMobileCategories()">
            ← Back to Sections
        </div>
        <div class="mobile-bestseller-header">
            <div class="header-icon">⭐</div>
            <div class="header-text">
                <h2>Best Seller</h2>
                <p>Featured products from all categories</p>
            </div>
        </div>
        <div class="mobile-bestseller-products-direct">
    `;
    
    if (bestSellerProducts.length === 0) {
        html += `
            <div class="mobile-empty-state">
                <div class="icon">⭐</div>
                <div class="message">No featured products yet</div>
                <div class="sub-message">Click "☆ Best Seller" button on any product to feature it here</div>
            </div>
        `;
    } else {
        bestSellerProducts.forEach(product => {
            const imageUrl = product.image || product.image_url || '';
            const productName = product.product_name || product.name || 'Unnamed Product';
            const price = product.price ? `₹${product.price.toFixed(2)}` : 'N/A';
            const weight = product.weight || '';
            const stock = product.stock || 0;
            const productId = product._id || product.id;
            
            // Category breadcrumb
            const categoryPath = `${product.category_section} → ${product.category_main} → ${product.category_sub}`;
            
            html += `
                <div class="mobile-bestseller-product-card" 
                     onclick="navigateToProductCategory('${product.category_section.replace(/'/g, "\\'")}', '${product.category_main.replace(/'/g, "\\'")}', '${product.category_sub.replace(/'/g, "\\'")}')">
                    <span class="bestseller-badge">⭐ Featured</span>
                    <button class="mobile-edit-btn" onclick="openEditMobileProduct('${productId}', event)" title="Edit Product">
                        ✏️
                    </button>
                    <button class="mobile-delete-btn" onclick="confirmDeleteMobileProduct('${productId}', '${productName.replace(/'/g, "\\'")}', event)" title="Delete Product">
                        🗑️
                    </button>
                    <div class="mobile-product-image">
                        ${imageUrl ? 
                            `<img src="${imageUrl}" alt="${productName}">` : 
                            '📦'
                        }
                    </div>
                    <div class="mobile-product-info">
                        <div class="mobile-product-name">${productName}</div>
                        <div class="mobile-product-category">📁 ${categoryPath}</div>
                        <div class="mobile-product-meta">${weight}</div>
                        <div class="mobile-product-price">${price}</div>
                        <div class="mobile-product-stock">Stock: ${stock}</div>
                    </div>
                </div>
            `;
        });
    }
    
    html += `
        </div>
    `;
    
    productsContainer.innerHTML = html;
}

// Show main category cards for a section (Level 2)
async function showMainCategoryCards(section) {
    console.log('%c📱 MOBILE VIEW: showMainCategoryCards() STARTED', 'color: #0066cc; font-weight: bold; font-size: 13px;');
    console.log('%c   For section:', 'color: #0066cc; font-size: 11px;', { section });
    
    // Update mobile view state
    mobileViewState.currentView = 'main-categories';
    mobileViewState.currentSection = section;
    mobileViewState.currentMainCategory = null;
    
    // CRITICAL FIX: Ensure containers are in correct state
    const categoriesContainer = document.getElementById('mobileCategorySections');
    const productsContainer = document.getElementById('mobileProductsList');
    
    console.log('%c1️⃣  Container validation:', 'color: #0066cc; font-weight: bold; font-size: 11px;', {
        categoriesContainer: !!categoriesContainer,
        productsContainer: !!productsContainer,
        productsContainerDisplay: productsContainer?.style.display
    });
    
    if (!productsContainer || !categoriesContainer) {
        console.error('%c❌ CRITICAL: Containers not found!', 'color: #ff0000; font-weight: bold; font-size: 11px;');
        return;
    }
    
    // Toggle visibility: hide sections, show products
    categoriesContainer.style.display = 'none';
    productsContainer.style.display = 'block';
    console.log('%c   ✅ Containers toggled: sections=none, products=block', 'color: #00aa00; font-size: 11px;');
    
    // Get category hierarchy for this section
    console.log('%c2️⃣  Searching for section in categoryHierarchy...', 'color: #0066cc; font-weight: bold; font-size: 11px;', {
        hierarchyLength: categoryHierarchy.length,
        lookingFor: section
    });
    
    // DEBUG: Show all sections in hierarchy
    console.log('%c   📋 Available sections in hierarchy:', 'color: #6666ff; font-size: 10px;');
    categoryHierarchy.forEach((item, idx) => {
        console.log(`      [${idx}] Section: "${item.section}" | Main cats: ${Object.keys(item.main_categories || {}).length}`);
    });
    
    const sectionCategory = categoryHierarchy.find(item => item.section === section);
    
    console.log('%c   ✅ Section found:', 'color: #00aa00; font-size: 11px;', {
        found: !!sectionCategory,
        hasMainCategories: !!sectionCategory?.main_categories,
        mainCategoriesCount: Object.keys(sectionCategory?.main_categories || {}).length,
        sectionDetails: sectionCategory
    });
    
    if (!sectionCategory || !sectionCategory.main_categories) {
        console.warn('%c   ⚠️  No main categories found for section: ' + section, 'color: #ff9900; font-size: 11px;');
        productsContainer.innerHTML = `
            <div class="mobile-back-button" onclick="showMobileCategories()">
                ← Back to Sections
            </div>
            <div class="mobile-empty-state">
                <div class="icon">📦</div>
                <div class="message">No categories configured for ${section}</div>
                <div class="sub-message">Click "Add New" below to create your first main category</div>
            </div>
            <div class="mobile-category-list">
                <div class="mobile-category-card mobile-category-add" onclick="openAddMainCategoryModal('${section.replace(/'/g, "\\'")}')">
                    <div class="icon">➕</div>
                    <div class="name">Add New</div>
                </div>
            </div>
        `;
        return;
    }
    
    // Fetch most bought items to check starred status
    console.log('%c3️⃣  Fetching most bought items...', 'color: #0066cc; font-weight: bold; font-size: 11px;');
    let mostBoughtItems = [];
    try {
        const timestamp = Date.now();
        const response = await fetch(`/admin/api/most-bought?t=${timestamp}`);
        console.log('   Response status:', response.status);
        
        if (response.ok) {
            const data = await response.json();
            mostBoughtItems = data.items || [];
            console.log('%c   ✅ Most bought items loaded:', 'color: #00aa00; font-size: 11px;', {
                count: mostBoughtItems.length,
                items: mostBoughtItems
            });
            
            // Show which items match current section
            const itemsForThisSection = mostBoughtItems.filter(item => item.section === section);
            console.log(`%c   📌 Starred items for section "${section}":`, 'color: #00aaff; font-weight: bold; font-size: 11px;', {
                count: itemsForThisSection.length,
                items: itemsForThisSection,
                mainCategories: itemsForThisSection.map(item => item.main_category)
            });
            
            if (itemsForThisSection.length === 0) {
                console.log('%c   💡 TIP: No starred categories in this section. Try starring one with the ⭐ button!', 'color: #ff9900; font-size: 11px;');
            }
        } else {
            console.warn('%c   ⚠️  Most bought API returned status:', 'color: #ff9900; font-size: 11px;', response.status);
        }
    } catch (error) {
        console.warn('%c   ⚠️  Error fetching most bought:', 'color: #ff9900; font-size: 11px;', error.message);
    }
    
    // Extract main categories (Level 2) - these are the keys of main_categories object
    console.log('%c4️⃣  Extracting main categories...', 'color: #0066cc; font-weight: bold; font-size: 11px;');
    const mainCategories = Object.keys(sectionCategory.main_categories);
    console.log('%c   ✅ Main categories extracted:', 'color: #00aa00; font-size: 11px;', {
        count: mainCategories.length,
        names: mainCategories
    });
    
    // Get section icon
    const sectionIcon = getCategoryIcon(section);
    
    let html = `
        <div class="mobile-back-button" onclick="showMobileCategories()">
            ← Back to Sections
        </div>
        <div class="mobile-search-container">
            <input type="text" 
                   id="mainCategorySearch" 
                   class="mobile-search-input" 
                   placeholder="🔍 Search main categories..."
                   onkeyup="searchMainCategories()">
        </div>
        <div class="mobile-category-list" id="mainCategoryCards">
    `;
    
    // Build main category cards
    console.log('%c5️⃣  Building main category cards...', 'color: #0066cc; font-weight: bold; font-size: 11px;');
    console.log('%c   📊 Main categories to render:', 'color: #6666ff; font-size: 10px;', mainCategories);
    mainCategories.forEach((mainCat, idx) => {
        const metadata = categoryMetadata[mainCat] || {};
        const imageUrl = metadata.image_url;
        const icon = getCategoryIcon(mainCat);
        
        // Check if this category is starred
        const isStarred = mostBoughtItems.some(item => 
            item.section === section && item.main_category === mainCat
        );
        
        console.log(`   Card ${idx + 1}/${mainCategories.length}: "${mainCat}"`, {
            hasImage: !!imageUrl,
            isStarred: isStarred,
            metadata: metadata
        });
        
        html += `
            <div class="mobile-category-card ${isStarred ? 'starred-category' : ''}" onclick="showSubCategoryProducts('${section.replace(/'/g, "\\'")}', '${mainCat.replace(/'/g, "\\'")}')">
                ${isStarred ? '<span class="starred-badge-hover">⭐ Starred</span>' : ''}
                <button class="star-category-btn ${isStarred ? 'starred' : ''}" onclick="toggleStarMainCategory('${section.replace(/'/g, "\\'")}', '${mainCat.replace(/'/g, "\\'")}', ${isStarred}, event)" title="${isStarred ? 'Unstar' : 'Star'} Main Category">
                    ${isStarred ? '★' : '⭐'}
                </button>
                <button class="edit-category-btn" onclick="openEditMainCategoryModal('${section.replace(/'/g, "\\'")}', '${mainCat.replace(/'/g, "\\'")}', event)" title="Edit Main Category">
                    ✏️
                </button>
                <button class="delete-category-btn" onclick="confirmDeleteMainCategory('${section.replace(/'/g, "\\'")}', '${mainCat.replace(/'/g, "\\'")}', event)" title="Delete Main Category">
                    🗑️
                </button>
                ${imageUrl ? 
                    `<img src="${imageUrl}" alt="${mainCat}" class="card-image" onerror="this.style.display='none'; this.nextElementSibling.style.display='flex';">
                    <div class="icon" style="display: none;">${icon}</div>` :
                    `<div class="icon">${icon}</div>`
                }
                <div class="name">${mainCat}</div>
            </div>
        `;
    });
    
    // Add "Add New Main Category" card
    html += `
            <div class="mobile-category-card mobile-category-add" onclick="openAddMainCategoryModal('${section.replace(/'/g, "\\'")}')">
                <div class="icon">➕</div>
                <div class="name">Add New</div>
            </div>
        </div>
    `;
    
    console.log('%c6️⃣  Setting innerHTML on container...', 'color: #0066cc; font-weight: bold; font-size: 11px;', {
        htmlLength: html.length
    });
    
    try {
        productsContainer.innerHTML = html;
        console.log('%c   ✅ innerHTML set successfully', 'color: #00aa00; font-size: 11px;');
        
        const renderedCards = productsContainer.querySelectorAll('.mobile-category-card');
        console.log('%c7️⃣  Verification - Cards rendered:', 'color: #0066cc; font-weight: bold; font-size: 11px;', {
            totalCards: renderedCards.length,
            expectedCards: mainCategories.length + 1
        });
    } catch (renderError) {
        console.error('%c   ❌ ERROR setting innerHTML:', 'color: #ff0000; font-weight: bold; font-size: 11px;', renderError);
        return;
    }
    
    // DEBUG: Check for starred badges and add hover event listeners
    console.log('%c8️⃣  Debugging Starred Badges:', 'color: #ff6600; font-weight: bold; font-size: 12px;');
    const starredCards = productsContainer.querySelectorAll('.mobile-category-card.starred-category');
    const starredBadges = productsContainer.querySelectorAll('.starred-badge-hover');
    
    console.log('%c   📊 Starred Elements Found:', 'color: #0066cc; font-size: 11px;', {
        starredCards: starredCards.length,
        starredBadges: starredBadges.length
    });
    
    starredBadges.forEach((badge, idx) => {
        console.log(`%c   Badge ${idx + 1}:`, 'color: #6666ff; font-size: 10px;', {
            element: badge,
            innerHTML: badge.innerHTML,
            computedStyle: {
                display: window.getComputedStyle(badge).display,
                opacity: window.getComputedStyle(badge).opacity,
                position: window.getComputedStyle(badge).position,
                zIndex: window.getComputedStyle(badge).zIndex,
                top: window.getComputedStyle(badge).top,
                left: window.getComputedStyle(badge).left
            },
            parentCard: badge.closest('.mobile-category-card'),
            hasStarredClass: badge.closest('.mobile-category-card')?.classList.contains('starred-category')
        });
    });
    
    // Add hover event listeners to starred cards for debugging
    starredCards.forEach((card, idx) => {
        const badge = card.querySelector('.starred-badge-hover');
        
        card.addEventListener('mouseenter', function() {
            console.log(`%c🖱️  HOVER START - Card ${idx + 1}`, 'color: #00ff00; font-weight: bold; font-size: 11px;');
            if (badge) {
                console.log('%c   Badge element:', 'color: #00ff00; font-size: 10px;', {
                    innerHTML: badge.innerHTML,
                    opacity: window.getComputedStyle(badge).opacity,
                    display: window.getComputedStyle(badge).display,
                    transform: window.getComputedStyle(badge).transform
                });
            } else {
                console.error('%c   ❌ No badge found in this card!', 'color: #ff0000; font-weight: bold;');
            }
        });
        
        card.addEventListener('mouseleave', function() {
            console.log(`%c🖱️  HOVER END - Card ${idx + 1}`, 'color: #ff9900; font-weight: bold; font-size: 11px;');
            if (badge) {
                console.log('%c   Badge opacity after hover:', 'color: #ff9900; font-size: 10px;', window.getComputedStyle(badge).opacity);
            }
        });
    });
    
    console.log('%c✅ showMainCategoryCards() COMPLETED SUCCESSFULLY', 'color: #00aa00; font-weight: bold; font-size: 13px;');
}

// Show subcategory products in sidebar layout (Level 3)
function showSubCategoryProducts(section, mainCategory) {
    // Update mobile view state
    mobileViewState.currentView = 'subcategories';
    mobileViewState.currentSection = section;
    mobileViewState.currentMainCategory = mainCategory;
    
    // CRITICAL FIX: Ensure containers are in correct state
    const categoriesContainer = document.getElementById('mobileCategorySections');
    const productsContainer = document.getElementById('mobileProductsList');
    
    if (!productsContainer || !categoriesContainer) {
        console.error('❌ CRITICAL: Containers not found for subcategory view!');
        return;
    }
    
    // Toggle visibility: hide sections, show products
    categoriesContainer.style.display = 'none';
    productsContainer.style.display = 'block';
    
    // Get category hierarchy for this section
    const sectionCategory = categoryHierarchy.find(item => item.section === section);
    
    if (!sectionCategory || !sectionCategory.main_categories || !sectionCategory.main_categories[mainCategory]) {
        productsContainer.innerHTML = `
            <div class="mobile-back-button" onclick="showMainCategoryCards('${section.replace(/'/g, "\\'")}')">
                ← Back to Main Categories
            </div>
            <div class="mobile-empty-state">
                <div class="icon">📦</div>
                <div class="message">No subcategories found for ${mainCategory}</div>
                <div class="sub-message">Click "Add New" below to create your first subcategory</div>
            </div>
            <div class="mobile-category-list">
                <div class="mobile-category-card mobile-category-add" onclick="openAddSubCategory('${section.replace(/'/g, "\\'")}', '${mainCategory.replace(/'/g, "\\'")}')">
                    <div class="icon">➕</div>
                    <div class="name">Add New</div>
                </div>
            </div>
        `;
        return;
    }
    
    // Get subcategories for this main category (Level 3)
    const subcategories = sectionCategory.main_categories[mainCategory];
    
    let html = `
        <div class="mobile-back-button" onclick="showMainCategoryCards('${section.replace(/'/g, "\\'")}')">
            ← Back to Main Categories
        </div>
        <div class="mobile-bestseller-layout">
            <div class="mobile-bestseller-sidebar">
                <div class="mobile-sidebar-categories">
    `;
    
    // Add sidebar subcategory items with images, edit and delete buttons
    subcategories.forEach((subCat, index) => {
        const isActive = index === 0 ? 'active' : '';
        const metadata = categoryMetadata[subCat] || {};
        const imageUrl = metadata.image_url;
        const icon = getCategoryIcon(subCat);
        
        html += `
            <div class="mobile-sidebar-item ${isActive}" onclick="selectSubCategory('${section.replace(/'/g, "\\'")}', '${mainCategory.replace(/'/g, "\\'")}', '${subCat.replace(/'/g, "\\'")}', this)">
                <button class="edit-btn" onclick="openEditSubCategoryModal('${section.replace(/'/g, "\\'")}', '${mainCategory.replace(/'/g, "\\'")}', '${subCat.replace(/'/g, "\\'")}', event)" title="Edit Subcategory">
                    ✏️
                </button>
                <button class="delete-btn" onclick="confirmDeleteSubCategory('${section.replace(/'/g, "\\'")}', '${mainCategory.replace(/'/g, "\\'")}', '${subCat.replace(/'/g, "\\'")}', event)" title="Delete Subcategory">
                    🗑️
                </button>
                ${imageUrl ? 
                    `<img src="${imageUrl}" alt="${subCat}" class="category-image" onerror="this.style.display='none'; this.nextElementSibling.style.display='block';">
                    <div class="icon" style="display: none;">${icon}</div>` :
                    `<div class="icon">${icon}</div>`
                }
                <div>${subCat}</div>
            </div>
        `;
    });
    
    // Add "Add New" subcategory button with main category context
    html += `
                    <div class="mobile-sidebar-item mobile-sidebar-add" onclick="openAddSubCategory('${section.replace(/'/g, "\\'")}', '${mainCategory.replace(/'/g, "\\'")}')">
                        <div class="icon">➕</div>
                        <div>Add New</div>
                    </div>
                </div>
            </div>
            <div class="mobile-bestseller-content" id="sectionContent">
                <!-- Products will be loaded here -->
            </div>
        </div>
    `;
    
    productsContainer.innerHTML = html;
    
    // Load products for first subcategory by default
    if (subcategories.length > 0) {
        loadSectionProducts(section, subcategories[0]);
    }
}

// Select a subcategory from sidebar
function selectSubCategory(section, mainCategory, subCategory, element) {
    // Remove active class from all sidebar items
    document.querySelectorAll('.mobile-sidebar-item').forEach(item => {
        item.classList.remove('active');
    });
    
    // Add active class to clicked item
    if (element) {
        element.classList.add('active');
    }
    
    // Load products for selected subcategory
    loadSectionProducts(section, subCategory);
}

// Navigate to product's original category (used in Best Seller section)
function navigateToProductCategory(section, mainCategory, subCategory) {
    console.log('=== NAVIGATING TO PRODUCT CATEGORY ===');
    console.log('Section:', section);
    console.log('Main Category:', mainCategory);
    console.log('Subcategory:', subCategory);
    
    // First, show the main categories for this section
    showMobileCategoryProducts(section);
    
    // Then navigate to the subcategory view
    setTimeout(() => {
        showSubCategoryProducts(section, mainCategory);
        
        // Then select the specific subcategory
        setTimeout(() => {
            // Find and click the subcategory in the sidebar
            const sidebarItems = document.querySelectorAll('.mobile-sidebar-item');
            sidebarItems.forEach(item => {
                const itemText = item.textContent.trim();
                if (itemText.includes(subCategory) && !itemText.includes('Add New')) {
                    item.classList.add('active');
                    loadSectionProducts(section, subCategory);
                }
            });
        }, 100);
    }, 100);
}

// Search main categories
function searchMainCategories() {
    const searchInput = document.getElementById('mainCategorySearch');
    const filter = searchInput.value.toLowerCase();
    const cards = document.querySelectorAll('#mainCategoryCards .mobile-category-card');
    
    cards.forEach(card => {
        const name = card.querySelector('.name').textContent.toLowerCase();
        if (name.includes(filter)) {
            card.style.display = '';
        } else {
            card.style.display = 'none';
        }
    });
}

// Show categories (back from products)
function showMobileCategories() {
    const categoriesContainer = document.getElementById('mobileCategorySections');
    const productsContainer = document.getElementById('mobileProductsList');
    
    // Reset mobile view state when going back to sections
    mobileViewState.currentView = 'sections';
    mobileViewState.currentSection = null;
    mobileViewState.currentMainCategory = null;
    
    // Show categories, hide products
    categoriesContainer.style.display = 'block';
    productsContainer.style.display = 'none';
}

// Load products for mobile view (not used anymore, kept for compatibility)
function loadMobileProducts() {
    // Products are now loaded on-demand when category is selected
    const container = document.getElementById('mobileProductsList');
    container.style.display = 'none';
}

// ============================================
// Unified Sidebar Layout (All Sections - 3 Level Navigation)
// ============================================

// Load products for a section category
function loadSectionProducts(section, category) {
    const contentContainer = document.getElementById('sectionContent');
    
    // Find the main category for this subcategory
    let mainCategory = '';
    const sectionData = categoryHierarchy.find(cat => cat.section === section);
    if (sectionData && sectionData.main_categories) {
        for (const [main, subs] of Object.entries(sectionData.main_categories)) {
            if (subs.includes(category)) {
                mainCategory = main;
                break;
            }
        }
    }
    
    // SPECIAL HANDLING FOR BEST SELLER SECTION
    // Best Seller shows products with is_best_seller=true from ALL categories
    let categoryProducts;
    if (section === 'Best Seller') {
        categoryProducts = allProducts.filter(product => product.is_best_seller === true);
        console.log('Best Seller products:', categoryProducts.length);
    } else {
        // Normal section: filter by section and subcategory
        categoryProducts = allProducts.filter(product => 
            product.category_section === section && 
            product.category_sub === category
        );
    }
    
    const sectionIcon = getCategoryIcon(section);
    const isBestSellerSection = section === 'Best Seller';
    
    let html = `
        <div class="mobile-bestseller-products">
            <div class="mobile-bestseller-products-title">
                <span>${sectionIcon}</span>
                <span>${category}</span>
                <button class="add-product-btn" onclick="openAddProductFromMobile('${section.replace(/'/g, "\\'")}', '${mainCategory.replace(/'/g, "\\'")}', '${category.replace(/'/g, "\\'")}')">
                    ➕ Add New
                </button>
            </div>
    `;
    
    if (categoryProducts.length === 0) {
        html += `
            <div class="mobile-empty-state">
                <div class="icon">📦</div>
                <div class="message">No products in ${category}</div>
                <div class="sub-message">Click "Add New" to add your first product</div>
            </div>
        `;
    } else {
    
    categoryProducts.forEach(product => {
        // Check 'image' first (updated by upload), then 'image_url' (set at creation)
        const imageUrl = product.image || product.image_url || '';
        const productName = product.product_name || product.name || 'Unnamed Product';
        const price = product.price ? `₹${product.price.toFixed(2)}` : 'N/A';
        const weight = product.weight || '';
        const stock = product.stock || 0;
        const productId = product._id || product.id;
        
        // For Best Seller section, make card clickable to navigate to original category
        const cardClickHandler = isBestSellerSection ? 
            `onclick="navigateToProductCategory('${product.category_section}', '${product.category_main}', '${product.category_sub}')" style="cursor: pointer;"` : 
            '';
        
        // Show category info for Best Seller products
        const categoryInfo = isBestSellerSection ? 
            `<div class="mobile-product-category">📁 ${product.category_section} → ${product.category_main} → ${product.category_sub}</div>` : 
            '';
        
        html += `
            <div class="mobile-bestseller-product-card" ${cardClickHandler}>
                ${isBestSellerSection ? '<span class="bestseller-badge">⭐ Featured</span>' : ''}
                <button class="mobile-edit-btn" onclick="openEditMobileProduct('${productId}', event)" title="Edit Product">
                    ✏️
                </button>
                <button class="mobile-delete-btn" onclick="confirmDeleteMobileProduct('${productId}', '${productName.replace(/'/g, "\\'")}', event)" title="Delete Product">
                    🗑️
                </button>
                <div class="mobile-product-image">
                    ${product.image || product.image_url ? 
                        `<img src="${imageUrl}" alt="${productName}">` : 
                        '📦'
                    }
                </div>
                <div class="mobile-product-info">
                    <div class="mobile-product-name">${productName}</div>
                    ${categoryInfo}
                    <div class="mobile-product-meta">${weight}</div>
                    <div class="mobile-product-price">${price}</div>
                    <div class="mobile-product-stock">Stock: ${stock}</div>
                </div>
            </div>
        `;
    });
    
    html += `
            <div style="text-align: center; padding: 10px; color: var(--text-gray); font-size: 12px;">
                ${categoryProducts.length} product${categoryProducts.length !== 1 ? 's' : ''} in ${category}
            </div>
    `;
    }
    
    html += `
        </div>
    `;
    
    contentContainer.innerHTML = html;
}

// Open dialog to add new category for any section
// Open modal to add a new Main Category (Level 2)
function openAddMainCategoryModal(section) {
    const modal = document.createElement('div');
    modal.id = 'addMainCategoryModal';
    modal.className = 'modal';
    modal.style.display = 'flex';
    
    modal.innerHTML = `
        <div class="modal-content" style="max-width: 550px;">
            <div class="modal-header" style="margin: 0 0 20px 0; margin-bottom: 20px;">
                <h2>➕ Add New Main Category to ${section}</h2>
                <button class="close-modal" onclick="closeAddMainCategoryModal()">&times;</button>
            </div>
            <form id="addMainCategoryForm" style="padding: 24px;" onsubmit="handleAddMainCategory(event, '${section.replace(/'/g, "\\'")}')">
                <div class="form-group" style="margin-bottom: 20px;">
                    <label>Section</label>
                    <input type="text" value="${section}" disabled style="background: #f5f5f5;">
                </div>
                
                <div class="form-group" style="margin-bottom: 20px;">
                    <label for="mainCategoryName">Main Category Name *</label>
                    <input type="text" id="mainCategoryName" required placeholder="e.g., Rice & Grains, Beverages, Snacks">
                    <span class="form-hint">🏷️ This will appear as a card in the main category view</span>
                </div>
                
                <div class="form-group" style="margin-bottom: 20px;">
                    <label for="mainCategoryNameTa">Main Category Name (Tamil)</label>
                    <input type="text" id="mainCategoryNameTa" placeholder="முக்கிய வகையின் பெயரை உள்ளிடவும்">
                </div>
                
                <div class="form-group" style="margin-bottom: 20px;">
                    <label>Upload Image <span style="color: red;">*</span></label>
                    <button type="button" class="btn-secondary" onclick="openInlineConverter('addMainCategoryConverterContainer', handleAddMainCategoryConverterResult)" style="width: 100%; background: #7B1FA2; color: white;">
                        🖼️ Open Image Converter
                    </button>
                    <span class="form-hint">📐 Click to convert your image to 400×400px automatically</span>
                </div>
                
                <div id="addMainCategoryConverterContainer" style="display: none;"></div>
                
                <div id="addMainCategoryImagePreview" class="image-preview" style="display: none; margin-bottom: 20px;">
                    <img id="addMainCategoryPreviewImg" alt="Preview" style="max-height: 150px; border-radius: 8px;">
                    <div style="margin-top: 8px; color: #4CAF50; font-size: 13px;">
                        ✅ Image ready to upload (400×400px)
                    </div>
                    <button type="button" class="btn-danger btn-sm" onclick="clearAddMainCategoryImagePreview()">✕ Remove</button>
                </div>
                
                <div class="modal-actions" style="padding-top: 20px; margin-top: 20px;">
                    <button type="button" class="btn-secondary" onclick="closeAddMainCategoryModal()">Cancel</button>
                    <button type="submit" class="btn-primary">✓ Add Main Category</button>
                </div>
            </form>
        </div>
    `;
    
    document.body.appendChild(modal);
}

// Close add main category modal
function closeAddMainCategoryModal() {
    const modal = document.getElementById('addMainCategoryModal');
    if (modal) {
        modal.remove();
    }
    // Reset converted file
    addMainCategoryConvertedFile = null;
}

// Global variable to store converted image for Add Main Category
let addMainCategoryConvertedFile = null;

// Callback when user clicks "Use Image" in inline converter
function handleAddMainCategoryConverterResult(file, blob) {
    addMainCategoryConvertedFile = file;
    
    // Show preview
    const preview = document.getElementById('addMainCategoryImagePreview');
    const previewImg = document.getElementById('addMainCategoryPreviewImg');
    
    if (preview && previewImg) {
        const reader = new FileReader();
        reader.onload = function(e) {
            previewImg.src = e.target.result;
            preview.style.display = 'block';
        };
        reader.readAsDataURL(file);
    }
}

// Clear add main category image preview
function clearAddMainCategoryImagePreview() {
    addMainCategoryConvertedFile = null;
    const preview = document.getElementById('addMainCategoryImagePreview');
    if (preview) preview.style.display = 'none';
    
    const previewImg = document.getElementById('addMainCategoryPreviewImg');
    if (previewImg) previewImg.src = '';
}

// Handle add main category form submission
async function handleAddMainCategory(event, section) {
    event.preventDefault();
    
    console.log('handleAddMainCategory called with section:', section);
    
    const mainCategoryName = document.getElementById('mainCategoryName').value.trim();
    const mainCategoryNameTa = document.getElementById('mainCategoryNameTa').value.trim();
    const imageFile = addMainCategoryConvertedFile; // Use converted image
    
    console.log('Form values - name:', mainCategoryName, 'name_ta:', mainCategoryNameTa, 'imageFile:', imageFile);
    
    if (!mainCategoryName) {
        showToast('Please enter a main category name', 'error');
        return;
    }
    
    // Validate that image is uploaded
    if (!imageFile) {
        showToast('Please convert and upload an image using the Image Converter', 'error');
        return;
        return;
    }
    
    try {
        showToast('Creating main category...', 'info');
        
        let imageUrl = null;
        
        // Upload image first (required)
        console.log('Uploading image for new main category...');
        const uploadResult = await uploadMainCategoryImage(imageFile);
        if (uploadResult && uploadResult.url) {
            imageUrl = uploadResult.url;
            console.log('Image uploaded successfully:', imageUrl);
        } else {
            showToast('Failed to upload image. Please try again.', 'error');
            return;
        }
        
        // Create the main category with image URL and Tamil name
        const requestBody = {
            section: section,
            main_category: mainCategoryName,
            image_url: imageUrl
        };
        if (mainCategoryNameTa) {
            requestBody.main_category_ta = mainCategoryNameTa;
        }
        
        console.log('Creating main category with request body:', requestBody);
        const response = await fetch('/admin/api/categories/main', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(requestBody)
        });
        
        console.log('Category creation response status:', response.status, response.statusText);
        
        if (response.ok) {
            const data = await response.json();
            console.log('Category creation successful:', data);
            showToast(data.message || 'Main category created successfully!', 'success');
            
            // Reload categories and metadata
            console.log('Reloading categories...');
            await loadCategories();
            console.log('Categories reloaded');
            
            // Close modal and refresh view
            console.log('Closing modal and refreshing view...');
            closeAddMainCategoryModal();
            showMainCategoryCards(section);
            console.log('Modal closed and view refreshed');
        } else {
            console.log('Category creation failed with status:', response.status);
            try {
                const error = await response.json();
                console.log('Error response:', error);
                showToast(error.detail || 'Failed to create main category', 'error');
            } catch (parseError) {
                console.log('Could not parse error response:', response.statusText);
                showToast(`Failed to create main category: ${response.statusText}`, 'error');
            }
        }
    } catch (error) {
        console.error('Error creating main category (catch block):', error);
        showToast('Error creating main category', 'error');
    }
}

// Handle Add Main Category image preview
async function handleAddMainCategoryImagePreview(event) {
    const file = event.target.files[0];
    if (!file) return;
    
    console.log('Add main category image selected:', file.name, 'Size:', file.size);
    
    // Validate file type
    const allowedTypes = ['image/jpeg', 'image/jpg', 'image/png', 'image/webp'];
    if (!allowedTypes.includes(file.type)) {
        showToast('Invalid file type. Please use JPG, PNG, or WEBP', 'error');
        event.target.value = '';
        return;
    }
    
    // Validate file size (800KB max)
    if (file.size > 800 * 1024) {
        showToast('Image too large. Maximum size is 800KB', 'error');
        event.target.value = '';
        return;
    }
    
    // Validate dimensions - Must be square (1:1 ratio)
    const reader = new FileReader();
    reader.onload = function(e) {
        const img = new Image();
        img.onload = function() {
            console.log('Image dimensions:', img.width, 'x', img.height);
            
            if (img.width !== img.height) {
                showToast('Image must be square (1:1 ratio). Example: 300x300px', 'error');
                event.target.value = '';
                return;
            }
            
            // Show preview
            const preview = document.getElementById('addMainCategoryImagePreview');
            const previewImg = document.getElementById('addMainCategoryPreviewImg');
            previewImg.src = e.target.result;
            preview.style.display = 'block';
            
            console.log('Image validation passed');
        };
        img.src = e.target.result;
    };
    reader.readAsDataURL(file);
}

// Clear Add Main Category image preview
function clearAddMainCategoryImagePreview() {
    document.getElementById('addMainCategoryImageFile').value = '';
    document.getElementById('addMainCategoryImagePreview').style.display = 'none';
    document.getElementById('addMainCategoryPreviewImg').src = '';
    showToast('Image removed', 'info');
}

function openAddSectionCategory(section) {
    // Create a dynamic modal for adding subcategory to the section
    const modal = document.createElement('div');
    modal.id = 'addSectionCategoryModal';
    modal.className = 'modal';
    modal.style.display = 'flex';
    
    modal.innerHTML = `
        <div class="modal-content" style="max-width: 500px;">
            <div class="modal-header">
                <h2>➕ Add New Category to ${section}</h2>
                <button class="close-modal" onclick="closeAddSectionCategoryModal()">&times;</button>
            </div>
            <form id="addSectionCategoryForm" onsubmit="handleAddSectionCategory(event, '${section.replace(/'/g, "\\'")}')">
                <div class="form-group">
                    <label>Section</label>
                    <input type="text" value="${section}" disabled style="background: #f5f5f5;">
                </div>
                
                <div class="form-group">
                    <label for="sectionCategoryMainGroup">Main Category Group *</label>
                    <select id="sectionCategoryMainGroup" required class="form-control">
                        <option value="">Select or type new group...</option>
                    </select>
                    <span class="form-hint">💡 Select existing group or type "__NEW__" to create new</span>
                </div>
                
                <div class="form-group" id="newMainGroupInput" style="display: none;">
                    <label for="sectionCategoryNewMainGroup">New Main Category Group Name *</label>
                    <input type="text" id="sectionCategoryNewMainGroup" placeholder="e.g., Rice & Grains, Beverages">
                    <span class="form-hint">🏷️ This groups subcategories together (e.g., Basmati Rice + Brown Rice)</span>
                </div>
                
                <div class="form-group">
                    <label for="sectionCategoryName">Subcategory Name * (Sidebar Item)</label>
                    <input type="text" id="sectionCategoryName" required placeholder="e.g., Basmati Rice, Soft Drinks">
                    <span class="form-hint">📱 This will appear as a clickable item in the mobile sidebar</span>
                </div>
                
                <div class="form-group">
                    <label for="sectionCategoryNameTa">Subcategory Name (Tamil)</label>
                    <input type="text" id="sectionCategoryNameTa" placeholder="துணைப்பிரிவு பெயரை உள்ளிடவும்">
                </div>
                
                <div class="form-group">
                    <label for="sectionCategoryImageUrl">Category Image URL (Optional)</label>
                    <input type="text" id="sectionCategoryImageUrl" placeholder="https://example.com/image.jpg">
                    <span class="form-hint">🖼️ Image will display in sidebar (45px height)</span>
                </div>
                
                <div class="form-group">
                    <label for="sectionCategoryImageFile">Upload Image (Optional)</label>
                    <input type="file" id="sectionCategoryImageFile" accept="image/*" onchange="handleSectionCategoryImageUpload(event)">
                    <span class="form-hint">📎 JPG, PNG, WebP • Max 2MB</span>
                </div>
                
                <div id="sectionCategoryImagePreview" class="image-preview" style="display: none;">
                    <img id="sectionCategoryPreviewImg" alt="Preview" style="max-height: 100px;">
                    <button type="button" class="btn-danger btn-sm" onclick="clearSectionCategoryImagePreview()">✕ Remove</button>
                </div>
                
                <div class="modal-actions">
                    <button type="button" class="btn-secondary" onclick="closeAddSectionCategoryModal()">Cancel</button>
                    <button type="submit" class="btn-primary">✓ Add Category</button>
                </div>
            </form>
        </div>
    `;
    
    document.body.appendChild(modal);
    
    // Populate main category groups dropdown
    populateSectionCategoryMainGroups(section);
    
    // Add change listener for main group dropdown
    document.getElementById('sectionCategoryMainGroup').addEventListener('change', function(e) {
        const newGroupInput = document.getElementById('newMainGroupInput');
        if (e.target.value === '__NEW__') {
            newGroupInput.style.display = 'block';
            document.getElementById('sectionCategoryNewMainGroup').required = true;
        } else {
            newGroupInput.style.display = 'none';
            document.getElementById('sectionCategoryNewMainGroup').required = false;
        }
    });
}

// Open add subcategory modal with pre-selected main category
function openAddSubCategory(section, mainCategory) {
    // Create a dynamic modal for adding subcategory with main category pre-selected
    const modal = document.createElement('div');
    modal.id = 'addSectionCategoryModal';
    modal.className = 'modal';
    modal.style.display = 'flex';
    
    modal.innerHTML = `
        <div class="modal-content" style="max-width: 550px;">
            <div class="modal-header" style="margin: 0 0 20px 0; margin-bottom: 20px;">
                <h2>➕ Add Subcategory to ${mainCategory}</h2>
                <button class="close-modal" onclick="closeAddSectionCategoryModal()">&times;</button>
            </div>
            <form id="addSectionCategoryForm" style="padding: 24px;" onsubmit="handleAddSectionCategory(event, '${section.replace(/'/g, "\\'")}')">
                <div class="form-group" style="margin-bottom: 20px;">
                    <label>Section</label>
                    <input type="text" value="${section}" disabled style="background: #f5f5f5;">
                </div>
                
                <div class="form-group" style="margin-bottom: 20px;">
                    <label>Main Category</label>
                    <input type="text" id="sectionCategoryMainGroup" value="${mainCategory}" disabled style="background: #f5f5f5;">
                    <span class="form-hint">💡 Subcategory will be added under ${mainCategory}</span>
                </div>
                
                <div class="form-group" style="margin-bottom: 20px;">
                    <label for="sectionCategoryName">Subcategory Name *</label>
                    <input type="text" id="sectionCategoryName" required placeholder="e.g., Coca Cola, Basmati Rice, Chocolate Bar">
                    <span class="form-hint">📱 This will appear in the sidebar under ${mainCategory}</span>
                </div>
                
                <div class="form-group" style="margin-bottom: 20px;">
                    <label for="sectionCategoryNameTa">Subcategory Name (Tamil)</label>
                    <input type="text" id="sectionCategoryNameTa" placeholder="துணைப்பிரிவு பெயரை உள்ளிடவும்" style="font-size: 16px;">
                    <span class="form-hint">🇮🇳 பொருந்தினால் தமிழ் பெயரைச் சேர்க்கவும்</span>
                </div>
                
                <div class="form-group" style="margin-bottom: 20px;">
                    <label>Upload Image <span style="color: red;">*</span></label>
                    <button type="button" class="btn-secondary" onclick="openInlineConverter('addSubcategoryConverterContainer', handleAddSubcategoryConverterResult)" style="width: 100%; background: #7B1FA2; color: white;">
                        🖼️ Open Image Converter
                    </button>
                    <span class="form-hint">📐 Click to convert your image to 400×400px automatically</span>
                </div>
                
                <div id="addSubcategoryConverterContainer" style="display: none;"></div>
                
                <div id="addSubCategoryImagePreview" class="image-preview" style="display: none; margin-bottom: 20px;">
                    <img id="addSubCategoryPreviewImg" alt="Preview" style="max-height: 100px;">
                    <div style="margin-top: 8px; color: #4CAF50; font-size: 13px;">
                        ✅ Image ready to upload (400×400px)
                    </div>
                    <button type="button" class="btn-danger btn-sm" onclick="clearAddSubCategoryImagePreview()">✕ Remove</button>
                </div>
                
                <div class="modal-actions" style="padding-top: 20px; margin-top: 20px;">
                    <button type="button" class="btn-secondary" onclick="closeAddSectionCategoryModal()">Cancel</button>
                    <button type="submit" class="btn-primary">✓ Add Subcategory</button>
                </div>
            </form>
        </div>
    `;
    
    document.body.appendChild(modal);
}

// Populate main category groups for section
function populateSectionCategoryMainGroups(section) {
    const dropdown = document.getElementById('sectionCategoryMainGroup');
    dropdown.innerHTML = '<option value="">Select main category group...</option>';
    
    // Find section in category hierarchy
    const sectionData = categoryHierarchy.find(item => item.section === section);
    
    if (sectionData && sectionData.main_categories) {
        // Add existing main category groups
        Object.keys(sectionData.main_categories).sort().forEach(mainCat => {
            const option = document.createElement('option');
            option.value = mainCat;
            option.textContent = mainCat;
            dropdown.appendChild(option);
        });
    }
    
    // Add "Create New" option
    const newOption = document.createElement('option');
    newOption.value = '__NEW__';
    newOption.textContent = '➕ Create New Main Category Group';
    dropdown.appendChild(newOption);
}

// Close add section category modal
function closeAddSectionCategoryModal() {
    const modal = document.getElementById('addSectionCategoryModal');
    if (modal) {
        modal.remove();
    }
}

// Global variable to store converted image for Add Subcategory
let addSubcategoryConvertedFile = null;

// Callback when user clicks "Use Image" in inline converter for Add Subcategory
function handleAddSubcategoryConverterResult(file, blob) {
    addSubcategoryConvertedFile = file;
    
    // Show preview
    const preview = document.getElementById('addSubCategoryImagePreview');
    const previewImg = document.getElementById('addSubCategoryPreviewImg');
    
    if (preview && previewImg) {
        const reader = new FileReader();
        reader.onload = function(e) {
            previewImg.src = e.target.result;
            preview.style.display = 'block';
        };
        reader.readAsDataURL(file);
    }
}

// Clear add subcategory image preview
function clearAddSubCategoryImagePreview() {
    addSubcategoryConvertedFile = null;
    const preview = document.getElementById('addSubCategoryImagePreview');
    if (preview) preview.style.display = 'none';
    
    const previewImg = document.getElementById('addSubCategoryPreviewImg');
    if (previewImg) previewImg.src = '';
}

// Handle section category image upload
async function handleSectionCategoryImageUpload(event) {
    const file = event.target.files[0];
    if (!file) return;
    
    // Validate file size (max 2MB)
    if (file.size > 2 * 1024 * 1024) {
        showToast('Image size must be less than 2MB', 'error');
        event.target.value = '';
        return;
    }
    
    // Validate file type
    if (!file.type.startsWith('image/')) {
        showToast('Please select a valid image file', 'error');
        event.target.value = '';
        return;
    }
    
    showToast('Uploading image...', 'info');
    
    try {
        const formData = new FormData();
        formData.append('file', file);
        
        const response = await fetch('/admin/api/upload-image', {
            method: 'POST',
            body: formData
        });
        
        if (!response.ok) {
            throw new Error('Failed to upload image');
        }
        
        const data = await response.json();
        
        // Handle both local (url) and Cloudinary (image_url) response formats
        const imageUrl = data.url || data.image_url;
        if (!imageUrl) {
            throw new Error('Invalid response format - missing image URL');
        }
        
        // Set the image URL
        document.getElementById('sectionCategoryImageUrl').value = imageUrl;
        
        // Show preview
        const preview = document.getElementById('sectionCategoryImagePreview');
        const previewImg = document.getElementById('sectionCategoryPreviewImg');
        previewImg.src = imageUrl;
        preview.style.display = 'block';
        
        showToast('Image uploaded successfully', 'success');
    } catch (error) {
        console.error('Error uploading image:', error);
        showToast('Failed to upload image', 'error');
        event.target.value = '';
    }
}

// Clear section category image preview
function clearSectionCategoryImagePreview() {
    document.getElementById('sectionCategoryImageUrl').value = '';
    document.getElementById('sectionCategoryImageFile').value = '';
    document.getElementById('sectionCategoryImagePreview').style.display = 'none';
}

// Handle add section category form submission
async function handleAddSectionCategory(event, section) {
    event.preventDefault();
    
    // Get main category from the form
    let mainCategory = null;
    const mainGroupElement = document.getElementById('sectionCategoryMainGroup');
    
    if (!mainGroupElement) {
        showToast('Form error: Main category element not found', 'error');
        console.error('sectionCategoryMainGroup element not found');
        return;
    }
    
    // Check if it's a select (dropdown) or input (disabled field)
    if (mainGroupElement.tagName === 'SELECT') {
        mainCategory = mainGroupElement.value.trim();
    } else if (mainGroupElement.tagName === 'INPUT') {
        mainCategory = mainGroupElement.value.trim();
    }
    
    const subcategoryNameElement = document.getElementById('sectionCategoryName');
    if (!subcategoryNameElement) {
        showToast('Form error: Subcategory name element not found', 'error');
        console.error('sectionCategoryName element not found');
        return;
    }
    
    const subcategoryName = subcategoryNameElement.value.trim();
    const subcategoryNameTaElement = document.getElementById('sectionCategoryNameTa');
    const subcategoryNameTa = subcategoryNameTaElement ? subcategoryNameTaElement.value.trim() : '';
    const imageFile = addSubcategoryConvertedFile; // Use converted image
    
    if (!mainCategory) {
        showToast('Main category is required', 'error');
        return;
    }
    
    if (!subcategoryName) {
        showToast('Please enter a subcategory name', 'error');
        return;
    }
    
    // MANDATORY VALIDATION
    if (!imageFile) {
        showToast('Please convert and upload an image using the Image Converter', 'error');
        return;
    }
    
    try {
        showToast('Creating subcategory...', 'info');
        
        // Upload image first (REQUIRED)
        console.log('Uploading image for new subcategory...');
        const uploadResult = await uploadSubCategoryImage(imageFile);
        
        if (!uploadResult || !uploadResult.url) {
            showToast('Failed to upload image. Please try again.', 'error');
            return;  // Stop if upload fails
        }
        
        const imageUrl = uploadResult.url;
        console.log('Image uploaded successfully:', imageUrl);
        
        // Add the subcategory with image URL and Tamil name
        const requestBody = {
            section: section,
            main_category: mainCategory,
            subcategory: subcategoryName,
            image_url: imageUrl
        };
        if (subcategoryNameTa) {
            requestBody.subcategory_ta = subcategoryNameTa;
        }
        
        const response = await fetch('/admin/api/categories/sub', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(requestBody)
        });
        
        if (!response.ok) {
            const error = await response.json();
            throw new Error(error.detail || 'Failed to add subcategory');
        }
        
        showToast('Subcategory added successfully!', 'success');
        
        // Close modal first
        closeAddSectionCategoryModal();
        
        // Reload categories - this will automatically restore the subcategory view
        await loadCategories();
        
    } catch (error) {
        console.error('Error adding category:', error);
        showToast(error.message || 'Failed to add category', 'error');
    }
}

// ============================================
// Mobile Product Delete Functions
// ============================================

// Confirm delete product from mobile view
function confirmDeleteMobileProduct(productId, productName, event) {
    // Stop propagation to prevent any parent click handlers
    if (event) {
        event.stopPropagation();
    }
    
    // Show confirmation modal
    const modal = document.createElement('div');
    modal.id = 'mobileDeleteConfirmModal';
    modal.className = 'mobile-delete-confirm-modal';
    modal.innerHTML = `
        <div class="mobile-delete-confirm-backdrop" onclick="closeMobileDeleteConfirm()"></div>
        <div class="mobile-delete-confirm-dialog">
            <div class="mobile-delete-confirm-header">
                <span class="mobile-delete-icon">⚠️</span>
                <h3>Delete Product?</h3>
            </div>
            <div class="mobile-delete-confirm-body">
                <p>Are you sure you want to delete:</p>
                <p class="mobile-delete-product-name">"${productName}"</p>
                <p class="mobile-delete-warning">This action cannot be undone!</p>
            </div>
            <div class="mobile-delete-confirm-actions">
                <button class="mobile-delete-cancel-btn" onclick="closeMobileDeleteConfirm()">
                    Cancel
                </button>
                <button class="mobile-delete-confirm-btn" onclick="deleteMobileProduct('${productId}')">
                    Delete
                </button>
            </div>
        </div>
    `;
    
    document.body.appendChild(modal);
    
    // Animate in
    setTimeout(() => {
        modal.classList.add('show');
    }, 10);
}

// Close mobile delete confirmation modal
function closeMobileDeleteConfirm() {
    const modal = document.getElementById('mobileDeleteConfirmModal');
    if (modal) {
        modal.classList.remove('show');
        setTimeout(() => {
            modal.remove();
        }, 300);
    }
}

// Delete product from mobile view
async function deleteMobileProduct(productId) {
    try {
        // Close confirmation modal
        closeMobileDeleteConfirm();
        
        // Show loading toast
        showToast('Deleting product...', 'info');
        
        // Call delete API
        const response = await fetch(`/admin/api/products/${productId}`, {
            method: 'DELETE'
        });
        
        if (response.ok) {
            showToast('Product deleted successfully!', 'success');
            
            // Store current view context before filtering
            const deletedProduct = allProducts.find(p => (p._id || p.id) === productId);
            const currentSection = deletedProduct?.category_section;
            const currentSubcategory = deletedProduct?.category_sub;
            
            // Remove product from allProducts array and reload from database
            await loadProducts();
            
            // Refresh the mobile view with the same section and subcategory
            if (currentSection && currentSubcategory) {
                setTimeout(() => {
                    loadSectionProducts(currentSection, currentSubcategory);
                }, 100);
            }
        } else {
            const error = await response.json();
            showToast(error.detail || 'Failed to delete product', 'error');
        }
    } catch (error) {
        console.error('Error deleting product:', error);
        showToast('Error deleting product', 'error');
    }
}

// Edit product from mobile view
function openEditMobileProduct(productId, event) {
    // Stop propagation to prevent any parent click handlers
    if (event) {
        event.stopPropagation();
    }
    
    // Store the current mobile view context for refresh after save
    const sectionContent = document.getElementById('sectionContent');
    if (sectionContent) {
        // Get current section and subcategory from the view
        const titleElement = document.querySelector('.mobile-bestseller-products-title span:last-child');
        if (titleElement) {
            sessionStorage.setItem('mobileEditContext', JSON.stringify({
                inMobileView: true,
                subcategory: titleElement.textContent
            }));
        }
    }
    
    // Use the existing editProduct function
    editProduct(productId);
}

// ============================================
// Category Delete Functions (Mobile View)
// ============================================

// Confirm delete section (Level 1)
function confirmDeleteSection(section, event) {
    console.log('%c🗑️ DELETE SECTION CALLED', 'color: #ff0000; font-weight: bold; font-size: 14px; background: #ffe0e0; padding: 5px;');
    console.log('   Section:', section);
    console.log('   Event:', event);
    
    // Stop propagation to prevent card click
    if (event) {
        console.log('   ✅ Stopping event propagation');
        event.stopPropagation();
        event.preventDefault();
    } else {
        console.warn('   ⚠️  No event object provided!');
    }
    
    // Show confirmation modal
    const modal = document.createElement('div');
    modal.id = 'deleteSectionModal';
    modal.className = 'modal';
    modal.style.display = 'flex';
    
    modal.innerHTML = `
        <div class="modal-content delete-confirm-modal">
            <div class="modal-header" style="background: linear-gradient(135deg, #dc2626 0%, #991b1b 100%);">
                <h2 style="color: white; display: flex; align-items: center; gap: 10px;">
                    <span class="warning-icon">⚠️</span>
                    Delete Section
                </h2>
            </div>
            <div class="modal-body" style="padding: 30px; text-align: center;">
                <div style="font-size: 48px; margin-bottom: 20px;">🗑️</div>
                <p style="font-size: 18px; font-weight: 600; margin-bottom: 15px;">
                    Delete section "<span style="color: var(--primary-green);">${section}</span>"?
                </p>
                <p style="color: #dc2626; font-weight: 600; margin-bottom: 10px;">
                    ⚠️ This action cannot be undone!
                </p>
                <p style="color: #666; font-size: 14px;">
                    This will delete the section and all its main categories and subcategories.
                </p>
            </div>
            <div class="modal-actions">
                <button type="button" class="btn-secondary" onclick="closeDeleteSectionModal()">Cancel</button>
                <button type="button" class="btn-danger" onclick="deleteSection('${section.replace(/'/g, "\\'")}')">
                    🗑️ Delete Section
                </button>
            </div>
        </div>
    `;
    
    document.body.appendChild(modal);
}

// Close delete section modal
function closeDeleteSectionModal() {
    const modal = document.getElementById('deleteSectionModal');
    if (modal) {
        modal.remove();
    }
}

// Delete section
async function deleteSection(section) {
    console.log('%c🗑️ DELETE SECTION FUNCTION CALLED', 'color: #ff0000; font-weight: bold; font-size: 14px; background: #ffe0e0; padding: 5px;');
    console.log('   Section to delete:', section);
    
    try {
        showToast('Deleting section...', 'info');
        
        console.log('   📡 Making DELETE request to:', `/admin/api/categories/section/${encodeURIComponent(section)}`);
        
        // Call backend API to delete section
        const response = await fetch(`/admin/api/categories/section/${encodeURIComponent(section)}`, {
            method: 'DELETE',
            headers: {
                'Cache-Control': 'no-cache, no-store, must-revalidate',
                'Pragma': 'no-cache',
                'Expires': '0'
            }
        });
        
        console.log('   📥 Response status:', response.status);
        console.log('   📥 Response ok:', response.ok);
        
        if (!response.ok) {
            const error = await response.json();
            console.error('   ❌ Delete failed:', error);
            throw new Error(error.detail || 'Failed to delete section');
        }
        
        const data = await response.json();
        console.log('   ✅ Delete successful:', data);
        showToast(data.message || 'Section deleted successfully!', 'success');
        
        // Reload categories from database
        console.log('   🔄 Reloading categories...');
        await loadCategories();
        
        // Close modal and refresh mobile view
        console.log('   🔄 Refreshing mobile view...');
        closeDeleteSectionModal();
        loadMobileCategorySections();
        
    } catch (error) {
        console.error('❌ Error deleting section:', error);
        showToast(error.message || 'Error deleting section', 'error');
    }
}

// Toggle star main category (add/remove from Most Bought)
// Debounce flag to prevent rapid star toggling
let isTogglingMostBought = false;

async function toggleStarMainCategory(section, mainCategory, isCurrentlyStarred, event) {
    // Stop propagation to prevent card click
    if (event) {
        event.stopPropagation();
    }
    
    // DEBOUNCE: Prevent rapid clicks
    if (isTogglingMostBought) {
        console.log('%c⚠️  DEBOUNCE: Already processing a star toggle, please wait...', 'color: #ff9900; font-weight: bold;');
        showToast('Please wait...', 'warning');
        return;
    }
    
    isTogglingMostBought = true;
    
    console.log('%c⭐ TOGGLE STAR MAIN CATEGORY - START', 'color: #ff6600; font-weight: bold; font-size: 14px;');
    console.log('%c1️⃣  Function Parameters:', 'color: #0066cc; font-weight: bold; font-size: 12px;', {
        section: section,
        sectionType: typeof section,
        mainCategory: mainCategory,
        mainCategoryType: typeof mainCategory,
        isCurrentlyStarred: isCurrentlyStarred,
        isCurrentlyStarredType: typeof isCurrentlyStarred
    });
    
    // VALIDATION: Check if parameters are correct
    if (!section || section === 'undefined' || section === 'null') {
        console.error('%c❌ ERROR: Invalid section parameter!', 'color: #ff0000; font-weight: bold;', section);
        showToast('Error: Invalid section', 'error');
        isTogglingMostBought = false;
        return;
    }
    
    if (!mainCategory || mainCategory === 'undefined' || mainCategory === 'null') {
        console.error('%c❌ ERROR: Invalid mainCategory parameter!', 'color: #ff0000; font-weight: bold;', mainCategory);
        showToast('Error: Invalid main category', 'error');
        isTogglingMostBought = false;
        return;
    }
    
    try {
        if (isCurrentlyStarred) {
            // Unstar - remove from Most Bought
            console.log('%c2️⃣  ACTION: UNSTAR (Remove from Most Bought)', 'color: #ff9900; font-weight: bold; font-size: 12px;');
            showToast('Removing from Most Bought...', 'warning');
            
            const deleteUrl = `/admin/api/most-bought?section=${encodeURIComponent(section)}&main_category=${encodeURIComponent(mainCategory)}`;
            console.log('%c3️⃣  DELETE Request URL:', 'color: #0066cc; font-size: 11px;', deleteUrl);
            
            const response = await fetch(deleteUrl, {
                method: 'DELETE',
                headers: {
                    'Cache-Control': 'no-cache'
                }
            });
            
            console.log('%c4️⃣  Response Status:', 'color: #0066cc; font-size: 11px;', response.status);
            const data = await response.json();
            console.log('%c5️⃣  Response Data:', 'color: #0066cc; font-size: 11px;', data);
            
            if (!response.ok) {
                console.error('%c❌ DELETE Failed:', 'color: #ff0000; font-weight: bold;', {
                    status: response.status,
                    detail: data.detail
                });
                showToast(data.detail || 'Failed to remove from Most Bought', 'error');
                isTogglingMostBought = false;
                return;
            }
            
            console.log('%c✅ Successfully removed from Most Bought', 'color: #00aa00; font-weight: bold;');
            showToast('Removed from Most Bought', 'success');
            
        } else {
            // Star - add to Most Bought
            console.log('%c2️⃣  ACTION: STAR (Add to Most Bought)', 'color: #ff9900; font-weight: bold; font-size: 12px;');
            showToast('⭐ Adding to Most Bought...', 'warning');
            
            const requestBody = {
                section: section,
                main_category: mainCategory
            };
            console.log('%c3️⃣  POST Request Body:', 'color: #0066cc; font-size: 11px;', requestBody);
            console.log('%c   Body as JSON:', 'color: #6666ff; font-size: 10px;', JSON.stringify(requestBody, null, 2));
            
            const response = await fetch('/admin/api/most-bought', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Cache-Control': 'no-cache'
                },
                body: JSON.stringify(requestBody)
            });
            
            console.log('%c4️⃣  Response Status:', 'color: #0066cc; font-size: 11px;', response.status);
            const data = await response.json();
            console.log('%c5️⃣  Response Data:', 'color: #0066cc; font-size: 11px;', data);
            
            if (!response.ok) {
                if (response.status === 409) {
                    console.warn('%c⚠️  409 Conflict: Already starred (possible race condition)', 'color: #ff9900; font-weight: bold;');
                    console.log('%c   This can happen if button was clicked multiple times rapidly', 'color: #6666ff; font-size: 10px;');
                    
                    // Item already exists - just refresh the UI to show correct state
                    showToast('⭐ Already in Most Bought section', 'info');
                    await showMainCategoryCards(section);
                    isTogglingMostBought = false;
                    return;
                } else {
                    console.error('%c❌ POST Failed:', 'color: #ff0000; font-weight: bold;', {
                        status: response.status,
                        detail: data.detail
                    });
                    showToast(data.detail || 'Failed to add to Most Bought', 'error');
                    isTogglingMostBought = false;
                    return;
                }
            }
            
            console.log('%c✅ Successfully added to Most Bought', 'color: #00aa00; font-weight: bold;');
            showToast('⭐ Added to Most Bought section!', 'success');
        }
        
        // Refresh the main category cards to update starred status
        console.log('%c6️⃣  Refreshing main category cards...', 'color: #0066cc; font-weight: bold; font-size: 12px;');
        await showMainCategoryCards(section);
        console.log('%c✅ TOGGLE STAR COMPLETED SUCCESSFULLY', 'color: #00aa00; font-weight: bold; font-size: 14px;');
        
    } catch (error) {
        console.error('%c❌ EXCEPTION in toggleStarMainCategory:', 'color: #ff0000; font-weight: bold; font-size: 14px;', error);
        console.error('%c   Error details:', 'color: #ff0000; font-size: 11px;', {
            message: error.message,
            stack: error.stack
        });
        showToast('Error updating Most Bought', 'error');
    } finally {
        // Always reset the debounce flag
        isTogglingMostBought = false;
    }
}

// Confirm delete main category (Level 2)
function confirmDeleteMainCategory(section, mainCategory, event) {
    // Stop propagation to prevent card click
    if (event) {
        event.stopPropagation();
    }
    
    // Show confirmation modal
    const modal = document.createElement('div');
    modal.id = 'deleteMainCategoryModal';
    modal.className = 'modal';
    modal.style.display = 'flex';
    
    modal.innerHTML = `
        <div class="modal-content delete-confirm-modal">
            <div class="modal-header" style="background: linear-gradient(135deg, #dc2626 0%, #991b1b 100%);">
                <h2 style="color: white; display: flex; align-items: center; gap: 10px;">
                    <span class="warning-icon">⚠️</span>
                    Delete Main Category
                </h2>
            </div>
            <div class="modal-body" style="padding: 30px; text-align: center;">
                <div style="font-size: 48px; margin-bottom: 20px;">🗑️</div>
                <p style="font-size: 18px; font-weight: 600; margin-bottom: 15px;">
                    Delete main category "<span style="color: var(--primary-green);">${mainCategory}</span>"?
                </p>
                <p style="color: #dc2626; font-weight: 600; margin-bottom: 10px;">
                    ⚠️ This action cannot be undone!
                </p>
                <p style="color: #666; font-size: 14px;">
                    This will delete the main category and all its subcategories from "${section}".
                </p>
            </div>
            <div class="modal-actions">
                <button type="button" class="btn-secondary" onclick="closeDeleteMainCategoryModal()">Cancel</button>
                <button type="button" class="btn-danger" onclick="deleteMainCategory('${section.replace(/'/g, "\\'")}', '${mainCategory.replace(/'/g, "\\'")}')">
                    🗑️ Delete Category
                </button>
            </div>
        </div>
    `;
    
    document.body.appendChild(modal);
}

// Close delete main category modal
function closeDeleteMainCategoryModal() {
    const modal = document.getElementById('deleteMainCategoryModal');
    if (modal) {
        modal.remove();
    }
}

// Delete main category
async function deleteMainCategory(section, mainCategory) {
    try {
        showToast('Deleting main category...', 'info');
        
        // Call backend API to delete main category
        const response = await fetch(`/admin/api/categories/main/${encodeURIComponent(section)}/${encodeURIComponent(mainCategory)}`, {
            method: 'DELETE'
        });
        
        if (!response.ok) {
            const error = await response.json();
            throw new Error(error.detail || 'Failed to delete main category');
        }
        
        const data = await response.json();
        showToast(data.message || 'Main category deleted successfully!', 'success');
        
        // Reload categories from database
        await loadCategories();
        
        // Close modal and refresh view - go back to main categories
        closeDeleteMainCategoryModal();
        showMainCategoryCards(section);
        
    } catch (error) {
        console.error('Error deleting main category:', error);
        showToast(error.message || 'Error deleting main category', 'error');
    }
}

// Confirm delete subcategory (Level 3)
function confirmDeleteSubCategory(section, mainCategory, subCategory, event) {
    // Stop propagation to prevent item selection
    if (event) {
        event.stopPropagation();
    }
    
    // Show confirmation modal
    const modal = document.createElement('div');
    modal.id = 'deleteSubCategoryModal';
    modal.className = 'modal';
    modal.style.display = 'flex';
    
    modal.innerHTML = `
        <div class="modal-content delete-confirm-modal">
            <div class="modal-header" style="background: linear-gradient(135deg, #dc2626 0%, #991b1b 100%);">
                <h2 style="color: white; display: flex; align-items: center; gap: 10px;">
                    <span class="warning-icon">⚠️</span>
                    Delete Subcategory
                </h2>
            </div>
            <div class="modal-body" style="padding: 30px; text-align: center;">
                <div style="font-size: 48px; margin-bottom: 20px;">🗑️</div>
                <p style="font-size: 18px; font-weight: 600; margin-bottom: 15px;">
                    Delete subcategory "<span style="color: var(--primary-green);">${subCategory}</span>"?
                </p>
                <p style="color: #dc2626; font-weight: 600; margin-bottom: 10px;">
                    ⚠️ This action cannot be undone!
                </p>
                <p style="color: #666; font-size: 14px;">
                    This will remove "${subCategory}" from "${mainCategory}" in "${section}".
                </p>
            </div>
            <div class="modal-actions">
                <button type="button" class="btn-secondary" onclick="closeDeleteSubCategoryModal()">Cancel</button>
                <button type="button" class="btn-danger" onclick="deleteSubCategory('${section.replace(/'/g, "\\'")}', '${mainCategory.replace(/'/g, "\\'")}', '${subCategory.replace(/'/g, "\\'")}')">
                    🗑️ Delete Subcategory
                </button>
            </div>
        </div>
    `;
    
    document.body.appendChild(modal);
}

// Close delete subcategory modal
function closeDeleteSubCategoryModal() {
    const modal = document.getElementById('deleteSubCategoryModal');
    if (modal) {
        modal.remove();
    }
}

// Delete subcategory
async function deleteSubCategory(section, mainCategory, subCategory) {
    try {
        showToast('Deleting subcategory...', 'info');
        
        // Call backend API to delete subcategory
        const response = await fetch(`/admin/api/categories/sub/${encodeURIComponent(section)}/${encodeURIComponent(mainCategory)}/${encodeURIComponent(subCategory)}`, {
            method: 'DELETE'
        });
        
        if (!response.ok) {
            const error = await response.json();
            throw new Error(error.detail || 'Failed to delete subcategory');
        }
        
        const data = await response.json();
        showToast(data.message || 'Subcategory deleted successfully!', 'success');
        
        // Reload categories from database
        await loadCategories();
        
        // Close modal and refresh sidebar view
        closeDeleteSubCategoryModal();
        showSubCategoryProducts(section, mainCategory);
        
    } catch (error) {
        console.error('Error deleting subcategory:', error);
        showToast(error.message || 'Error deleting subcategory', 'error');
    }
}

// ============================================
// ============================================
// Category Edit Functions - Section Modal Only
// ============================================

// 1. SECTION EDIT MODAL (Level 1 - Section Cards)
// Only allows changing the section name, no image upload
function openEditSectionModal(sectionName, event) {
    if (event) event.stopPropagation();
    
    console.log('📋 Opening edit section modal:', sectionName);
    
    const modal = document.getElementById('editSectionModal');
    document.getElementById('editSectionOldName').value = sectionName;
    document.getElementById('editSectionName').value = sectionName;
    
    // Load current Tamil name from hierarchy
    const sectionDoc = categoryHierarchy.find(s => s.section === sectionName);
    document.getElementById('editSectionNameTa').value = sectionDoc?.section_ta || '';
    
    console.log('✅ Section modal opened with values:', {
        oldName: sectionName,
        newName: sectionName,
        tamilName: sectionDoc?.section_ta || '(not set)'
    });
    
    modal.style.display = 'flex';
}

function closeEditSectionModal() {
    document.getElementById('editSectionModal').style.display = 'none';
    document.getElementById('editSectionForm').reset();
}

async function handleSectionEdit(event) {
    event.preventDefault();
    
    console.log('🔧 STEP 1: handleSectionEdit() called');
    
    const oldName = document.getElementById('editSectionOldName').value;
    const newName = document.getElementById('editSectionName').value.trim();
    const newNameTa = document.getElementById('editSectionNameTa').value.trim();
    
    console.log('🔧 STEP 2: Form values extracted:', {
        oldName,
        newName,
        newNameTa,
        oldName_length: oldName.length,
        newName_length: newName.length
    });
    
    if (!newName) {
        console.log('❌ STEP 3: Validation failed - empty name');
        showToast('Section name is required', 'error');
        return;
    }
    
    // Get old Tamil name from hierarchy
    const sectionDoc = categoryHierarchy.find(s => s.section === oldName);
    const oldNameTa = sectionDoc?.section_ta || '';
    
    console.log('🔧 STEP 3: Found section in hierarchy:', {
        sectionDoc_found: !!sectionDoc,
        oldNameTa
    });
    
    // Normalize empty values for comparison (undefined, null, empty string all treated as empty)
    const normalizedNewNameTa = newNameTa || '';
    const normalizedOldNameTa = oldNameTa || '';
    
    // Check if anything actually changed
    if (newName === oldName && normalizedNewNameTa === normalizedOldNameTa) {
        console.log('⚠️  STEP 4: No changes detected, just closing modal');
        closeEditSectionModal();
        return; // Don't make API call if nothing changed!
    }
    
    console.log('📝 STEP 4: Changes detected:', {
        nameChanged: newName !== oldName,
        tamilChanged: normalizedNewNameTa !== normalizedOldNameTa,
        oldName,
        newName,
        oldNameTa: normalizedOldNameTa,
        newNameTa: normalizedNewNameTa
    });
    
    try {
        showToast('Updating section...', 'info');
        
        const requestBody = {};
        if (newName !== oldName) {
            requestBody.new_name = newName;
        }
        // Always include section_ta (even if empty, to allow clearing)
        requestBody.section_ta = newNameTa;
        
        console.log('🔧 STEP 5: Request body prepared:', requestBody);
        
        const url = `/admin/api/categories/section/${encodeURIComponent(oldName)}`;
        console.log('🔧 STEP 6: Making PUT request to:', url);
        
        const response = await fetch(url, {
            method: 'PUT',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(requestBody)
        });
        
        console.log('🔧 STEP 7: Response received:', {
            status: response.status,
            ok: response.ok,
            statusText: response.statusText
        });
        
        const responseData = await response.json();
        console.log('🔧 STEP 8: Response data:', responseData);
        
        if (response.ok) {
            showToast('Section updated successfully', 'success');
            console.log('✅ STEP 9: Update successful');
            
            // CRITICAL: Update mobileViewState if section name changed
            if (newName !== oldName && mobileViewState.currentSection === oldName) {
                console.log(`🔄 STEP 10: Updating mobileViewState section: "${oldName}" → "${newName}"`);
                mobileViewState.currentSection = newName;
            }
            
            console.log('🔧 STEP 11: Closing modal...');
            closeEditSectionModal();
            
            console.log('🔧 STEP 12: Calling loadCategories()...');
            await loadCategories(); // This will automatically restore the view
            console.log('✅ STEP 13: Section edit complete!');
        } else {
            console.log('❌ STEP 9: Update failed:', responseData);
            showToast('Failed to update section', 'error');
        }
    } catch (error) {
        console.error('❌ ERROR in handleSectionEdit:', error);
        showToast('Error updating section', 'error');
    }
}

// ============================================
// ============================================
// 2. MAIN CATEGORY EDIT MODAL (Level 2)
// ============================================

// Open edit modal for main category
function openEditMainCategoryModal(section, mainCategoryName, event) {
    if (event) event.stopPropagation();
    
    const modal = document.getElementById('editMainCategoryModal');
    const metadata = categoryMetadata[mainCategoryName] || {};
    
    console.log('📋 Opening edit modal for main category:', {
        section: section,
        mainCategoryName: mainCategoryName,
        metadata: metadata,
        name_ta: metadata.name_ta || '(not set)'
    });
    
    // Set form values
    document.getElementById('editMainCategoryOldName').value = mainCategoryName;
    document.getElementById('editMainCategorySection').value = section;
    document.getElementById('editMainCategorySectionDisplay').value = section;
    document.getElementById('editMainCategoryName').value = mainCategoryName;
    
    // Load Tamil name from metadata
    const tamilInput = document.getElementById('editMainCategoryNameTa');
    tamilInput.value = metadata.name_ta || '';
    console.log('📝 Set Tamil input to:', tamilInput.value);
    
    // Show existing image if available
    const preview = document.getElementById('editMainCategoryImagePreview');
    const previewImg = document.getElementById('editMainCategoryPreviewImg');
    
    if (metadata.image_url) {
        previewImg.src = metadata.image_url;
        preview.style.display = 'block';
    } else {
        preview.style.display = 'none';
    }
    
    // Reset converted file
    editMainCategoryConvertedFile = null;
    
    modal.style.display = 'flex';
}

// Global variable to store converted image for Edit Main Category
let editMainCategoryConvertedFile = null;

// Callback when user clicks "Use Image" in inline converter
function handleEditMainCategoryConverterResult(file, blob) {
    editMainCategoryConvertedFile = file;
    
    // Show preview
    const preview = document.getElementById('editMainCategoryImagePreview');
    const previewImg = document.getElementById('editMainCategoryPreviewImg');
    
    if (preview && previewImg) {
        const reader = new FileReader();
        reader.onload = function(e) {
            previewImg.src = e.target.result;
            preview.style.display = 'block';
        };
        reader.readAsDataURL(file);
    }
}

// Clear edit main category image
function clearEditMainCategoryImage() {
    editMainCategoryConvertedFile = null;
    const preview = document.getElementById('editMainCategoryImagePreview');
    if (preview) preview.style.display = 'none';
    
    const previewImg = document.getElementById('editMainCategoryPreviewImg');
    if (previewImg) previewImg.src = '';
}

function closeEditMainCategoryModal() {
    document.getElementById('editMainCategoryModal').style.display = 'none';
    document.getElementById('editMainCategoryForm').reset();
    document.getElementById('editMainCategoryImagePreview').style.display = 'none';
    // Reset converted file
    editMainCategoryConvertedFile = null;
}

async function handleMainCategoryEdit(event) {
    event.preventDefault();
    
    const oldName = document.getElementById('editMainCategoryOldName').value;
    const newName = document.getElementById('editMainCategoryName').value.trim();
    const newNameTa = document.getElementById('editMainCategoryNameTa').value.trim();
    const section = document.getElementById('editMainCategorySection').value;
    const imageFile = editMainCategoryConvertedFile; // Use converted image
    
    if (!newName) {
        showToast('Main category name is required', 'error');
        return;
    }
    
    // Get old values from metadata
    const oldMetadata = categoryMetadata[oldName] || {};
    const oldNameTa = oldMetadata.name_ta || '';
    const oldImageUrl = oldMetadata.image_url || '';
    
    // Get current image URL (either new converted file or existing)
    let currentImageUrl = oldImageUrl;
    if (imageFile) {
        // New image selected - will be different
        currentImageUrl = 'NEW_IMAGE';
    } else {
        const previewImg = document.getElementById('editMainCategoryPreviewImg');
        if (previewImg && previewImg.src && !previewImg.src.includes('blob:')) {
            currentImageUrl = previewImg.src;
        }
    }
    
    // Normalize empty values
    const normalizedNewNameTa = newNameTa || '';
    const normalizedOldNameTa = oldNameTa || '';
    
    // Check if anything actually changed
    if (newName === oldName && 
        normalizedNewNameTa === normalizedOldNameTa && 
        !imageFile &&
        currentImageUrl === oldImageUrl) {
        console.log('⚠️  No changes detected, just closing modal');
        closeEditMainCategoryModal();
        return;
    }
    
    console.log('📝 Changes detected:', {
        nameChanged: newName !== oldName,
        tamilChanged: normalizedNewNameTa !== normalizedOldNameTa,
        imageChanged: imageFile !== null || currentImageUrl !== oldImageUrl,
        oldName,
        newName,
        oldNameTa: normalizedOldNameTa,
        newNameTa: normalizedNewNameTa
    });
    
    try {
        showToast('Updating main category...', 'info');
        
        let imageUrl = null;
        
        // Upload new image if converted
        if (imageFile) {
            const uploadResult = await uploadMainCategoryImage(imageFile);
            if (uploadResult) {
                imageUrl = uploadResult.url;
            } else {
                showToast('Failed to upload image, but continuing with name update', 'warning');
            }
        } else {
            // Keep existing image if no new one
            const previewImg = document.getElementById('editMainCategoryPreviewImg');
            if (previewImg && previewImg.src && !previewImg.src.includes('blob:')) {
                imageUrl = previewImg.src;
            }
        }
        
        // Update main category with Tamil name
        const requestBody = {
            section: section,
            image_url: imageUrl,
            name_ta: newNameTa  // Backend expects 'name_ta' field
        };
        if (newName !== oldName) {
            requestBody.new_name = newName;
        }
        
        console.log('📤 Sending update request for main category:', {
            oldName: oldName,
            newName: newName,
            section: section,
            newNameTa: newNameTa,
            requestBody: requestBody
        });
        
        const response = await fetch(`/admin/api/categories/main/${encodeURIComponent(oldName)}`, {
            method: 'PUT',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(requestBody)
        });
        
        if (response.ok) {
            const result = await response.json();
            console.log('✅ Main category updated successfully', result);
            showToast('Main category updated successfully', 'success');
            
            // CRITICAL: Update mobileViewState if main category name changed
            if (newName !== oldName && mobileViewState.currentMainCategory === oldName) {
                console.log(`🔄 Updating mobileViewState: "${oldName}" → "${newName}"`);
                mobileViewState.currentMainCategory = newName;
            }
            
            closeEditMainCategoryModal();
            
            // If name changed (CASCADE happened), force full reload
            if (result.reload_required) {
                console.log('🔄 CASCADE UPDATE detected - Forcing full reload');
                showToast(`Category renamed: "${result.old_name}" → "${result.new_name}". Reloading...`, 'success');
                
                // Wait a bit for CASCADE to complete, then reload
                setTimeout(async () => {
                    await loadCategories();
                    console.log('🔄 Reloading products view');
                    await loadProducts();

                    if (mobileViewState.currentView === 'main-categories' && mobileViewState.currentSection === section) {
                        console.log('🔄 Refreshing mobile main category cards');
                        await showMainCategoryCards(section);
                    } else if (mobileViewState.currentView === 'subcategories' && mobileViewState.currentSection === section && mobileViewState.currentMainCategory === newName) {
                        console.log('🔄 Refreshing subcategory product view');
                        await showSubCategoryProducts(section, newName);
                    }
                }, 500); // 500ms delay to ensure CASCADE completes
            } else {
                // Just metadata update (Tamil name, image), normal reload
                await loadCategories();
            }
        } else {
            const error = await response.json();
            console.error('❌ Failed to update:', error);
            showToast(error.detail || 'Failed to update main category', 'error');
        }
    } catch (error) {
        console.error('Error updating main category:', error);
        showToast('Error updating main category', 'error');
    }
}

async function handleEditMainCategoryImagePreview(event) {
    const file = event.target.files[0];
    if (!file) return;
    
    console.log('Main category image selected:', file.name, 'Size:', file.size);
    
    // Validate file type
    const allowedTypes = ['image/jpeg', 'image/jpg', 'image/png', 'image/webp'];
    if (!allowedTypes.includes(file.type)) {
        showToast('Invalid file type. Please use JPG, PNG, or WEBP', 'error');
        event.target.value = '';
        return;
    }
    
    // Validate file size (800KB max)
    if (file.size > 800 * 1024) {
        showToast('Image too large. Maximum size is 800KB', 'error');
        event.target.value = '';
        return;
    }
    
    // Validate dimensions - Must be square (1:1 ratio)
    const reader = new FileReader();
    reader.onload = function(e) {
        const img = new Image();
        img.onload = function() {
            console.log('Image dimensions:', img.width, 'x', img.height);
            
            if (img.width !== img.height) {
                showToast('Image must be square (1:1 ratio). Example: 300x300px', 'error');
                event.target.value = '';
                return;
            }
            
            // Show preview
            const preview = document.getElementById('editMainCategoryImagePreview');
            const previewImg = document.getElementById('editMainCategoryPreviewImg');
            previewImg.src = e.target.result;
            preview.style.display = 'block';
            
            console.log('Image validation passed');
        };
        img.src = e.target.result;
    };
    reader.readAsDataURL(file);
}

async function uploadMainCategoryImage(file) {
    try {
        const formData = new FormData();
        formData.append('file', file);
        formData.append('category_type', 'main_category');
        
        console.log('Starting image upload for main category, file:', file.name, 'size:', file.size);
        const response = await fetch('/admin/api/upload-image', {
            method: 'POST',
            body: formData
        });
        
        console.log('Image upload response status:', response.status, response.statusText);
        
        if (!response.ok) {
            console.log('Image upload failed with status:', response.status);
            throw new Error('Failed to upload image');
        }
        
        const result = await response.json();
        console.log('Image upload result:', result);
        
        // Handle both local (url) and Cloudinary (image_url) response formats
        if (!result.url && !result.image_url) {
            console.error('Image upload response missing url/image_url:', result);
            throw new Error('Invalid response format - missing image URL');
        }
        
        // Normalize response to always have 'url' property
        const normalizedResult = {
            ...result,
            url: result.url || result.image_url
        };
        
        console.log('Normalized upload result:', normalizedResult);
        return normalizedResult;
    } catch (error) {
        console.error('Error uploading main category image:', error);
        return null;
    }
}

function clearEditMainCategoryImage() {
    const fileInput = document.getElementById('editMainCategoryImageFile');
    const preview = document.getElementById('editMainCategoryImagePreview');
    const previewImg = document.getElementById('editMainCategoryPreviewImg');
    
    fileInput.value = '';
    previewImg.src = '';
    preview.style.display = 'none';
    
    showToast('Image removed', 'info');
}

// ============================================
// SUBCATEGORY EDIT MODAL FUNCTIONS (Level 3)
// ============================================

// Open edit subcategory modal with current data
function openEditSubCategoryModal(section, mainCategory, subCategoryName, event) {
    if (event) event.stopPropagation();
    
    const modal = document.getElementById('editSubCategoryModal');
    const metadata = categoryMetadata[subCategoryName] || {};
    
    console.log('📋 Opening edit subcategory modal:', {
        section: section,
        mainCategory: mainCategory,
        subCategoryName: subCategoryName,
        metadata: metadata,
        name_ta: metadata.name_ta || '(not set)'
    });
    
    // Set hidden fields
    document.getElementById('editSubCategoryOldName').value = subCategoryName;
    document.getElementById('editSubCategorySection').value = section;
    document.getElementById('editSubCategoryMainCategory').value = mainCategory;
    
    // Set display fields (disabled)
    document.getElementById('editSubCategorySectionDisplay').value = section;
    document.getElementById('editSubCategoryMainCategoryDisplay').value = mainCategory;
    
    // Set editable name field
    document.getElementById('editSubCategoryName').value = subCategoryName;
    
    // Load Tamil name from metadata
    const tamilInput = document.getElementById('editSubCategoryNameTa');
    tamilInput.value = metadata.name_ta || '';
    console.log('📝 Set Tamil input to:', tamilInput.value);
    
    // Show existing image if available
    const preview = document.getElementById('editSubCategoryImagePreview');
    const previewImg = document.getElementById('editSubCategoryPreviewImg');
    
    if (metadata.image_url) {
        previewImg.src = metadata.image_url;
        preview.style.display = 'block';
    } else {
        preview.style.display = 'none';
    }
    
    modal.style.display = 'flex';
}

// Close edit subcategory modal
function closeEditSubCategoryModal() {
    const modal = document.getElementById('editSubCategoryModal');
    modal.style.display = 'none';
    
    // Reset form
    document.getElementById('editSubCategoryForm').reset();
    document.getElementById('editSubCategoryImagePreview').style.display = 'none';
    // Reset converted file
    editSubcategoryConvertedFile = null;
}

// Global variable to store converted image for Edit Subcategory
let editSubcategoryConvertedFile = null;

// Callback when user clicks "Use Image" in inline converter for Edit Subcategory
function handleEditSubcategoryConverterResult(file, blob) {
    editSubcategoryConvertedFile = file;
    
    // Show preview
    const preview = document.getElementById('editSubCategoryImagePreview');
    const previewImg = document.getElementById('editSubCategoryPreviewImg');
    
    if (preview && previewImg) {
        const reader = new FileReader();
        reader.onload = function(e) {
            previewImg.src = e.target.result;
            preview.style.display = 'block';
        };
        reader.readAsDataURL(file);
    }
}

// Clear edit subcategory image
function clearEditSubCategoryImage() {
    editSubcategoryConvertedFile = null;
    const preview = document.getElementById('editSubCategoryImagePreview');
    if (preview) preview.style.display = 'none';
    
    const previewImg = document.getElementById('editSubCategoryPreviewImg');
    if (previewImg) previewImg.src = '';
}

// ===== PRODUCT IMAGE CONVERTER INTEGRATION =====
// Global variable to store converted image for Product (Add/Edit)
let productConvertedFile = null;

// Callback when user clicks "Use Image" in inline converter for Product
function handleProductConverterResult(file, blob) {
    productConvertedFile = file;
    
    // Show preview
    const preview = document.getElementById('productImagePreview');
    const previewImg = document.getElementById('productPreviewImg');
    
    if (preview && previewImg) {
        const reader = new FileReader();
        reader.onload = function(e) {
            previewImg.src = e.target.result;
            preview.style.display = 'block';
        };
        reader.readAsDataURL(file);
    }
}

// Clear product image
function clearProductImage() {
    productConvertedFile = null;
    const preview = document.getElementById('productImagePreview');
    if (preview) preview.style.display = 'none';
    
    const previewImg = document.getElementById('productPreviewImg');
    if (previewImg) previewImg.src = '';
}
// ===== END PRODUCT IMAGE CONVERTER INTEGRATION =====

// Handle subcategory edit submission
async function handleSubCategoryEdit(event) {
    event.preventDefault();
    
    const oldName = document.getElementById('editSubCategoryOldName').value;
    const newName = document.getElementById('editSubCategoryName').value.trim();
    const newNameTa = document.getElementById('editSubCategoryNameTa').value.trim();
    const section = document.getElementById('editSubCategorySection').value;
    const mainCategory = document.getElementById('editSubCategoryMainCategory').value;
    const imageFile = editSubcategoryConvertedFile; // Use converted image
    
    if (!newName) {
        showToast('Please enter a subcategory name', 'error');
        return;
    }
    
    // Get old values from metadata
    const oldMetadata = categoryMetadata[oldName] || {};
    const oldNameTa = oldMetadata.name_ta || '';
    const oldImageUrl = oldMetadata.image_url || '';
    
    // Get current image URL
    let currentImageUrl = oldImageUrl;
    if (imageFile) {
        currentImageUrl = 'NEW_IMAGE';
    } else {
        const previewImg = document.getElementById('editSubCategoryPreviewImg');
        if (previewImg && previewImg.src && !previewImg.src.includes('blob:')) {
            currentImageUrl = previewImg.src;
        }
    }
    
    // Normalize empty values
    const normalizedNewNameTa = newNameTa || '';
    const normalizedOldNameTa = oldNameTa || '';
    
    // Check if anything actually changed
    if (newName === oldName && 
        normalizedNewNameTa === normalizedOldNameTa && 
        !imageFile &&
        currentImageUrl === oldImageUrl) {
        console.log('⚠️  No changes detected, just closing modal');
        closeEditSubCategoryModal();
        return;
    }
    
    console.log('📝 Changes detected:', {
        nameChanged: newName !== oldName,
        tamilChanged: normalizedNewNameTa !== normalizedOldNameTa,
        imageChanged: imageFile !== null || currentImageUrl !== oldImageUrl,
        oldName,
        newName,
        oldNameTa: normalizedOldNameTa,
        newNameTa: normalizedNewNameTa
    });
    
    try {
        showToast('Updating subcategory...', 'info');
        
        let imageUrl = null;
        
        // Upload new converted image if selected
        if (imageFile) {
            console.log('Uploading new image for subcategory...');
            const uploadResult = await uploadSubCategoryImage(imageFile);
            if (uploadResult && uploadResult.url) {
                imageUrl = uploadResult.url;
                console.log('New image uploaded:', imageUrl);
            } else {
                showToast('Failed to upload image', 'error');
                return;
            }
        } else {
            // Keep existing image
            const previewImg = document.getElementById('editSubCategoryPreviewImg');
            if (previewImg && previewImg.src && !previewImg.src.includes('blob:')) {
                imageUrl = previewImg.src;
                console.log('Keeping existing image:', imageUrl);
            }
        }
        
        // Update subcategory with Tamil name
        const requestBody = {
            section: section,
            main_category: mainCategory,
            image_url: imageUrl,
            name_ta: newNameTa  // Backend expects 'name_ta' field
        };
        if (newName !== oldName) {
            requestBody.new_name = newName;
        }
        
        console.log('📤 Sending subcategory update request:', {
            oldName: oldName,
            newName: newName,
            section: section,
            mainCategory: mainCategory,
            newNameTa: newNameTa,
            requestBody: requestBody
        });
        
        // Use the correct endpoint with CASCADE product updates
        const response = await fetch(`/admin/api/subcategory/${encodeURIComponent(section)}/${encodeURIComponent(mainCategory)}/${encodeURIComponent(oldName)}`, {
            method: 'PUT',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(requestBody)
        });
        
        if (!response.ok) {
            const error = await response.json();
            throw new Error(error.detail || 'Failed to update subcategory');
        }
        
        showToast('Subcategory updated successfully!', 'success');
        
        // Close modal first
        closeEditSubCategoryModal();
        
        // Reload categories - this will automatically restore the subcategory view
        await loadCategories();
        
    } catch (error) {
        console.error('Error updating subcategory:', error);
        showToast(error.message || 'Failed to update subcategory', 'error');
    }
}

// Handle image preview for edit subcategory modal
async function handleEditSubCategoryImagePreview(event) {
    const file = event.target.files[0];
    if (!file) return;
    
    console.log('Image selected for subcategory:', file.name, 'Size:', file.size);
    
    // Validate file type
    const allowedTypes = ['image/jpeg', 'image/jpg', 'image/png', 'image/webp'];
    if (!allowedTypes.includes(file.type)) {
        showToast('Invalid file type. Please use JPG, PNG, or WEBP', 'error');
        event.target.value = '';
        return;
    }
    
    // Validate file size (800KB max)
    if (file.size > 800 * 1024) {
        showToast('Image too large. Maximum size is 800KB', 'error');
        event.target.value = '';
        return;
    }
    
    // Validate dimensions - Must be square (1:1 ratio)
    const reader = new FileReader();
    reader.onload = function(e) {
        const img = new Image();
        img.onload = function() {
            console.log('Image dimensions:', img.width, 'x', img.height);
            
            if (img.width !== img.height) {
                showToast('Image must be square (1:1 ratio). Example: 300x300px', 'error');
                event.target.value = '';
                return;
            }
            
            // Show preview
            const preview = document.getElementById('editSubCategoryImagePreview');
            const previewImg = document.getElementById('editSubCategoryPreviewImg');
            previewImg.src = e.target.result;
            preview.style.display = 'block';
            
            console.log('Subcategory image validation passed');
        };
        img.src = e.target.result;
    };
    reader.readAsDataURL(file);
}

// Upload subcategory image to server
async function uploadSubCategoryImage(file) {
    try {
        const formData = new FormData();
        formData.append('file', file);
        formData.append('category_type', 'subcategory');
        
        console.log('Starting image upload for subcategory, file:', file.name, 'size:', file.size);
        const response = await fetch('/admin/api/upload-image', {
            method: 'POST',
            body: formData
        });
        
        console.log('Image upload response status:', response.status, response.statusText);
        
        if (!response.ok) {
            console.log('Image upload failed with status:', response.status);
            throw new Error('Failed to upload image');
        }
        
        const result = await response.json();
        console.log('Subcategory image uploaded:', result);
        
        // Handle both local (url) and Cloudinary (image_url) response formats
        if (!result.url && !result.image_url) {
            console.error('Image upload response missing url/image_url:', result);
            throw new Error('Invalid response format - missing image URL');
        }
        
        // Normalize response to always have 'url' property
        const normalizedResult = {
            ...result,
            url: result.url || result.image_url
        };
        
        console.log('Normalized upload result:', normalizedResult);
        return normalizedResult;
    } catch (error) {
        console.error('Error uploading subcategory image:', error);
        return null;
    }
}

// Clear image from edit subcategory modal
function clearEditSubCategoryImage() {
    const fileInput = document.getElementById('editSubCategoryImageFile');
    const preview = document.getElementById('editSubCategoryImagePreview');
    const previewImg = document.getElementById('editSubCategoryPreviewImg');
    
    fileInput.value = '';
    previewImg.src = '';
    preview.style.display = 'none';
    
    showToast('Image removed', 'info');
}

// Handle image preview for ADD subcategory modal
async function handleAddSubCategoryImagePreview(event) {
    const file = event.target.files[0];
    if (!file) return;
    
    console.log('Image selected for new subcategory:', file.name, 'Size:', file.size);
    
    // Validate file type
    const allowedTypes = ['image/jpeg', 'image/jpg', 'image/png', 'image/webp'];
    if (!allowedTypes.includes(file.type)) {
        showToast('Invalid file type. Please use JPG, PNG, or WEBP', 'error');
        event.target.value = '';
        return;
    }
    
    // Validate file size (800KB max)
    if (file.size > 800 * 1024) {
        showToast('Image too large. Maximum size is 800KB', 'error');
        event.target.value = '';
        return;
    }
    
    // Validate dimensions - Must be square (1:1 ratio)
    const reader = new FileReader();
    reader.onload = function(e) {
        const img = new Image();
        img.onload = function() {
            console.log('Image dimensions:', img.width, 'x', img.height);
            
            if (img.width !== img.height) {
                showToast('Image must be square (1:1 ratio). Example: 300x300px', 'error');
                event.target.value = '';
                return;
            }
            
            // Show preview
            const preview = document.getElementById('addSubCategoryImagePreview');
            const previewImg = document.getElementById('addSubCategoryPreviewImg');
            previewImg.src = e.target.result;
            preview.style.display = 'block';
            
            console.log('Subcategory image validation passed');
        };
        img.src = e.target.result;
    };
    reader.readAsDataURL(file);
}

// Clear image from ADD subcategory modal
function clearAddSubCategoryImagePreview() {
    const fileInput = document.getElementById('addSubCategoryImageFile');
    const preview = document.getElementById('addSubCategoryImagePreview');
    const previewImg = document.getElementById('addSubCategoryPreviewImg');
    
    fileInput.value = '';
    previewImg.src = '';
    preview.style.display = 'none';
    
    showToast('Image removed', 'info');
}

// ============================================
// OLD FUNCTIONS - Kept for backward compatibility
// ============================================

// Open add new category modal
function openAddCategoryModal() {
    const modal = document.getElementById('addCategoryModal');
    
    // Reset form
    document.getElementById('addCategoryForm').reset();
    
    modal.style.display = 'flex';
}

// Close add category modal
function closeAddCategoryModal() {
    const modal = document.getElementById('addCategoryModal');
    modal.style.display = 'none';
    document.getElementById('addCategoryForm').reset();
}



// Handle add category form submission
async function handleAddCategory(event) {
    event.preventDefault();
    
    const categoryName = document.getElementById('addCategoryName').value.trim();
    const categoryNameTa = document.getElementById('addCategoryNameTa').value.trim();
    
    if (!categoryName) {
        showToast('Category name is required', 'error');
        return;
    }
    
    try {
        showToast('Creating category...', 'info');
        
        // Create the section with Tamil name
        const requestBody = { section: categoryName };
        if (categoryNameTa) {
            requestBody.section_ta = categoryNameTa;
        }
        
        console.log('=== CREATING NEW SECTION ===');
        console.log('Request body:', JSON.stringify(requestBody));
        
        const createResponse = await fetch('/admin/api/categories/section', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(requestBody)
        });
        
        console.log('Response status:', createResponse.status);
        console.log('Response ok:', createResponse.ok);
        
        const responseData = await createResponse.json();
        console.log('Response data:', responseData);
        
        if (createResponse.ok) {
            console.log('✓ Section created successfully');
            showToast('Category created successfully', 'success');
            
            // Reload categories and mobile preview
            await loadCategories();
            loadMobileCategorySections();
            
            // Close modal
            closeAddCategoryModal();
        } else if (createResponse.status === 401) {
            showToast('Session expired. Please refresh the page and login again.', 'error');
        } else {
            console.error('✗ Failed to create section:', responseData);
            showToast(responseData.detail || 'Failed to create category', 'error');
        }
    } catch (error) {
        console.error('Error creating category:', error);
        showToast('Failed to create category: ' + error.message, 'error');
    }
}

// Handle category image upload
async function handleCategoryImageUpload(event) {
    const file = event.target.files[0];
    if (!file) return;
    
    // Validate file size (max 2MB)
    if (file.size > 2 * 1024 * 1024) {
        showToast('Image size must be less than 2MB', 'error');
        event.target.value = '';
        return;
    }
    
    // Validate file type
    if (!file.type.startsWith('image/')) {
        showToast('Please select a valid image file', 'error');
        event.target.value = '';
        return;
    }
    
    // Show loading
    showToast('Uploading image...', 'info');
    
    try {
        const formData = new FormData();
        formData.append('file', file);
        
        const response = await fetch('/admin/api/upload-image', {
            method: 'POST',
            body: formData
        });
        
        if (!response.ok) {
            if (response.status === 401) {
                throw new Error('Session expired. Please refresh the page and login again.');
            }
            const errorData = await response.json().catch(() => ({}));
            throw new Error(errorData.detail || 'Failed to upload image');
        }
        
        const data = await response.json();
        
        // Handle both local (url) and Cloudinary (image_url) response formats
        const imageUrl = data.url || data.image_url;
        if (!imageUrl) {
            throw new Error('Invalid response format - missing image URL');
        }
        
        // Set the image URL in the form
        document.getElementById('editCategoryImageUrl').value = imageUrl;
        
        // Show preview
        const preview = document.getElementById('editCategoryImagePreview');
        const previewImg = document.getElementById('editCategoryPreviewImg');
        previewImg.src = imageUrl;
        preview.style.display = 'block';
        
        showToast('Image uploaded successfully', 'success');
    } catch (error) {
        console.error('Error uploading image:', error);
        showToast('Failed to upload image', 'error');
        event.target.value = '';
    }
}

// Clear category image preview
function clearCategoryImagePreview() {
    document.getElementById('editCategoryImageUrl').value = '';
    document.getElementById('editCategoryImageFile').value = '';
    document.getElementById('editCategoryImagePreview').style.display = 'none';
}

// Handle category edit form submission
async function handleCategoryEdit(event) {
    event.preventDefault();
    
    const oldName = document.getElementById('editCategoryOldName').value;
    const newName = document.getElementById('editCategoryName').value.trim();
    const imageUrl = document.getElementById('editCategoryImageUrl').value.trim();
    
    if (!newName) {
        showToast('Category name is required', 'error');
        return;
    }
    
    try {
        showToast('Updating category...', 'info');
        
        const response = await fetch(`/admin/api/categories/section/${encodeURIComponent(oldName)}`, {
            method: 'PUT',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                new_name: newName !== oldName ? newName : null,
                image_url: imageUrl || null
            })
        });
        
        if (response.ok) {
            const data = await response.json();
            showToast(data.message || 'Category updated successfully', 'success');
            
            // Reload categories and mobile preview
            await loadCategories();
            
            // Check current view and refresh accordingly
            const modal = document.getElementById('editCategoryModal');
            const section = modal.getAttribute('data-section');
            
            const bestSellerLayout = document.querySelector('.mobile-bestseller-layout');
            const mainCategoryCards = document.getElementById('mainCategoryCards');
            
            if (bestSellerLayout) {
                // Reload Best Seller layout
                showBestSellerLayout();
            } else if (mainCategoryCards && section) {
                // Reload main category cards view (Level 2)
                showMainCategoryCards(section);
            } else if (mainCategoryCards) {
                // Reload normal category view
                loadMobileCategorySections();
            } else {
                // Reload normal category view
                loadMobileCategorySections();
            }
            
            // Close modal
            closeEditCategoryModal();
        } else if (response.status === 401) {
            showToast('Session expired. Please refresh the page and login again.', 'error');
        }
        // Silently ignore other errors - no error message shown
    } catch (error) {
        console.error('Error updating category:', error);
        // Silently ignore errors - no toast message shown
    }
}

// Get icon for category section
function getCategoryIcon(section) {
    const icons = {
        'Best Seller': '⭐',
        'Groceries': '🛒',
        'Personal Care': '🧴',
        'Snacks': '🍪',
        'Beverages': '🥤',
        'Dairy': '🥛',
        'Fruits': '🍎',
        'Vegetables': '🥬',
        'Meat': '🍗',
        'Bakery': '🍞',
        // Main category icons (for sidebar items)
        'Soft Drinks': '🥤',
        'Juices': '🧃',
        'Energy Drinks': '⚡',
        'Basmati Rice': '🍚',
        'Non-Basmati Rice': '🌾',
        'Wheat Flour': '🌾',
        'Pulses': '🫘',
        'Cooking Oil': '🫗',
        'Ghee': '🧈',
        'Salt': '🧂',
        'Sugar': '🍬',
        'Spices': '🌶️',
        'Tea & Coffee': '☕',
        'Biscuits': '🍪',
        'Namkeen': '🥨',
        'Chips': '🥔',
        'Chocolates': '🍫',
        'Candies': '🍬'
    };
    return icons[section] || '🏷️';
}
