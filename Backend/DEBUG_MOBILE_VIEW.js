/**
 * DEBUGGING ENHANCEMENT FOR MOBILE VIEW WHITE SCREEN
 * 
 * This file contains enhanced versions of mobile view functions with detailed logging
 * to help identify the white screen issue.
 * 
 * INSTALLATION:
 * 1. Copy this file to Backend/static/admin/js/debug_mobile_view.js
 * 2. Add this line to admin_dashboard.html BEFORE main dashboard.js loads:
 *    <script src="/static/admin/js/debug_mobile_view.js"></script>
 * 
 * 3. Then in Chrome DevTools Console, run:
 *    enableMobileViewDebugging()
 */

let MOBILE_VIEW_DEBUG = {
    enabled: false,
    logs: [],
    errors: []
};

function log(message, data = null) {
    const timestamp = new Date().toLocaleTimeString();
    const logEntry = `[${timestamp}] ${message}`;
    MOBILE_VIEW_DEBUG.logs.push(logEntry);
    
    if (data) {
        console.log(`%c${logEntry}`, 'color: #0066cc; font-weight: bold;', data);
    } else {
        console.log(`%c${logEntry}`, 'color: #0066cc; font-weight: bold;');
    }
}

function logError(message, error = null) {
    const timestamp = new Date().toLocaleTimeString();
    const errorEntry = `❌ [${timestamp}] ${message}`;
    MOBILE_VIEW_DEBUG.errors.push(errorEntry);
    
    console.error(`%c${errorEntry}`, 'color: #ff0000; font-weight: bold;', error);
}

function logWarning(message, data = null) {
    const timestamp = new Date().toLocaleTimeString();
    const warnEntry = `⚠️  [${timestamp}] ${message}`;
    
    if (data) {
        console.warn(`%c${warnEntry}`, 'color: #ff9900; font-weight: bold;', data);
    } else {
        console.warn(`%c${warnEntry}`, 'color: #ff9900; font-weight: bold;');
    }
}

/**
 * ENHANCED: loadMobileCategorySections with detailed debugging
 */
function loadMobileCategorySections_DEBUG() {
    log('📱 MOBILE: loadMobileCategorySections() STARTED');
    
    try {
        const container = document.getElementById('mobileCategorySections');
        
        // CHECK 1: Container exists?
        if (!container) {
            logError('CRITICAL: Container #mobileCategorySections not found in DOM');
            return false;
        }
        log('✅ Container #mobileCategorySections found', container);
        
        // CHECK 2: categoryHierarchy exists and has data?
        if (!categoryHierarchy) {
            logError('CRITICAL: categoryHierarchy is undefined');
            return false;
        }
        log('✅ categoryHierarchy exists', { length: categoryHierarchy.length });
        
        if (categoryHierarchy.length === 0) {
            logWarning('No categories in hierarchy (empty database)', categoryHierarchy);
        }
        
        // BUILD HTML
        log('📝 Building HTML content...');
        let html = '<div class="mobile-category-title">📂 Sections</div>';
        
        if (categoryHierarchy && categoryHierarchy.length > 0) {
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
        
        // Extract sections
        log('🔍 Extracting sections from categoryHierarchy...');
        const sectionsSet = new Set();
        let sectionsFound = 0;
        
        categoryHierarchy.forEach((item, index) => {
            if (!item) {
                logWarning(`Item at index ${index} is null/undefined`);
                return;
            }
            
            if (item.section && item.section !== null && item.section !== 'undefined') {
                sectionsSet.add(item.section);
                sectionsFound++;
            }
            
            if (Array.isArray(item.sections)) {
                item.sections.forEach(s => {
                    if (s && s !== null && s !== 'undefined') {
                        sectionsSet.add(s);
                        sectionsFound++;
                    }
                });
            }
        });
        
        const sections = Array.from(sectionsSet).sort();
        log('✅ Sections extracted', { count: sections.length, sections: sections });
        
        // CHECK 3: Any sections found?
        if (sections.length === 0) {
            logWarning('No sections found in categoryHierarchy');
        }
        
        // Generate section cards
        sections.forEach((section, idx) => {
            log(`  Creating section card ${idx + 1}/${sections.length}: "${section}"`);
            
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
        
        if (sections.length === 0) {
            html += `
                <div class="mobile-empty-state-inline">
                    <div class="icon">📂</div>
                    <div class="message">No sections yet. Click "Add Section" to get started!</div>
                </div>
            `;
        }
        
        // Add new section button
        html += `
            <div class="mobile-category-card mobile-add-category-card" data-category-name="add new" onclick="openAddCategoryModal()">
                <div class="name">➕ Add Section</div>
            </div>
        `;
        
        html += '</div>';
        
        // CHECK 4: HTML generated?
        if (!html || html.length === 0) {
            logError('CRITICAL: HTML content is empty');
            return false;
        }
        log(`✅ HTML generated: ${html.length} characters`);
        
        // SET CONTENT
        log('📥 Setting innerHTML on container...');
        try {
            container.innerHTML = html;
            log('✅ innerHTML set successfully');
        } catch (e) {
            logError('CRITICAL: Failed to set innerHTML', e);
            return false;
        }
        
        // CHECK 5: Content actually rendered?
        log('🔍 Verifying rendered content...');
        const renderedCards = container.querySelectorAll('.mobile-category-card');
        log(`✅ Rendered cards: ${renderedCards.length}`);
        
        if (renderedCards.length === 0 && sections.length > 0) {
            logWarning('WARNING: HTML set but no cards rendered', {
                containerHTML: container.innerHTML.substring(0, 200),
                containerDisplay: window.getComputedStyle(container).display,
                containerVisibility: window.getComputedStyle(container).visibility
            });
        }
        
        // HIDE PRODUCTS
        const productsContainer = document.getElementById('mobileProductsList');
        if (productsContainer) {
            productsContainer.style.display = 'none';
            log('✅ Products container hidden');
        } else {
            logWarning('Products container #mobileProductsList not found');
        }
        
        log('✅ loadMobileCategorySections() COMPLETED SUCCESSFULLY');
        return true;
        
    } catch (error) {
        logError('CRITICAL EXCEPTION in loadMobileCategorySections()', error);
        console.error('Full stack:', error.stack);
        return false;
    }
}

/**
 * ENHANCED: showMobileCategoryProducts with detailed debugging
 */
function showMobileCategoryProducts_DEBUG(categorySection) {
    log(`📱 MOBILE: showMobileCategoryProducts('${categorySection}') STARTED`);
    
    try {
        const categoriesContainer = document.getElementById('mobileCategorySections');
        const productsContainer = document.getElementById('mobileProductsList');
        
        // CHECK containers
        if (!categoriesContainer) {
            logError('CRITICAL: Categories container not found');
            return false;
        }
        if (!productsContainer) {
            logError('CRITICAL: Products container not found');
            return false;
        }
        
        log('✅ Both containers found');
        
        // Hide/show containers
        categoriesContainer.style.display = 'none';
        productsContainer.style.display = 'block';
        log('✅ Container visibility toggled');
        
        // Handle Best Seller specially
        if (categorySection === 'Best Seller') {
            log('📌 Detected Best Seller section - calling showBestSellerProducts_DEBUG()');
            return showBestSellerProducts_DEBUG();
        } else {
            log(`📌 Normal section: ${categorySection} - calling showMainCategoryCards_DEBUG()`);
            return showMainCategoryCards_DEBUG(categorySection);
        }
        
    } catch (error) {
        logError('CRITICAL EXCEPTION in showMobileCategoryProducts()', error);
        return false;
    }
}

/**
 * ENHANCED: showMainCategoryCards with detailed debugging
 */
function showMainCategoryCards_DEBUG(categorySection) {
    log(`📱 MOBILE: showMainCategoryCards('${categorySection}') STARTED`);
    
    try {
        const productsContainer = document.getElementById('mobileProductsList');
        
        if (!productsContainer) {
            logError('CRITICAL: Products container not found');
            return false;
        }
        
        // Filter main categories for this section
        const mainCategories = categoryHierarchy.filter(item => 
            (item.section === categorySection || (Array.isArray(item.sections) && item.sections.includes(categorySection)))
        );
        
        log(`✅ Filtered main categories: ${mainCategories.length} found for section "${categorySection}"`, {
            section: categorySection,
            categories: mainCategories.map(c => c.main_category || c.name)
        });
        
        if (mainCategories.length === 0) {
            logWarning(`No main categories found for section: ${categorySection}`);
        }
        
        // Build HTML
        let html = `
            <div class="mobile-back-button" onclick="showMobileCategories()">
                ← Back to Sections
            </div>
            <div class="mobile-section-header">
                <h2>${categorySection}</h2>
                <p>Select a category to view products</p>
            </div>
            <div class="mobile-main-category-grid" id="mobilMainCategoryGrid">
        `;
        
        if (mainCategories.length === 0) {
            html += `
                <div class="mobile-empty-state">
                    <div class="icon">📁</div>
                    <div class="message">No categories in this section</div>
                </div>
            `;
        } else {
            mainCategories.forEach(cat => {
                const name = cat.main_category || cat.name || 'Unnamed';
                const metaKey = `${categorySection}__${name}`;
                const metadata = categoryMetadata[metaKey];
                const productCount = cat.product_count || 0;
                
                html += `
                    <div class="mobile-main-category-card" 
                         onclick="showMobileSubCategories('${categorySection.replace(/'/g, "\\'")}', '${name.replace(/'/g, "\\'")}')">
                        ${metadata && metadata.image_url ? 
                            `<img src="${metadata.image_url}" alt="${name}">` : 
                            '<div class="placeholder-image">📦</div>'
                        }
                        <div class="mobile-category-name">${name}</div>
                        <div class="mobile-category-count">${productCount} products</div>
                    </div>
                `;
            });
        }
        
        html += '</div>';
        
        log(`✅ HTML built: ${html.length} characters`);
        
        // Set content
        try {
            productsContainer.innerHTML = html;
            log('✅ innerHTML set successfully');
            
            // Verify rendering
            const renderedCards = productsContainer.querySelectorAll('.mobile-main-category-card');
            log(`✅ Rendered main category cards: ${renderedCards.length}`);
            
            return true;
        } catch (e) {
            logError('CRITICAL: Failed to set innerHTML', e);
            return false;
        }
        
    } catch (error) {
        logError('CRITICAL EXCEPTION in showMainCategoryCards()', error);
        return false;
    }
}

/**
 * ENHANCED: showBestSellerProducts with detailed debugging
 */
function showBestSellerProducts_DEBUG() {
    log('⭐ MOBILE: showBestSellerProducts() STARTED');
    
    try {
        const productsContainer = document.getElementById('mobileProductsList');
        
        if (!productsContainer) {
            logError('CRITICAL: Products container not found');
            return false;
        }
        
        // Filter best seller products
        const bestSellerProducts = allProducts.filter(p => p.is_best_seller === true);
        log(`✅ Best seller products found: ${bestSellerProducts.length}`);
        
        // Build HTML
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
                </div>
            `;
        } else {
            bestSellerProducts.forEach(product => {
                const productName = product.product_name || product.name || 'Unnamed';
                const imageUrl = product.image || product.image_url || '';
                
                html += `
                    <div class="mobile-bestseller-product-card">
                        <span class="bestseller-badge">⭐ Featured</span>
                        <div class="mobile-product-image">
                            ${imageUrl ? `<img src="${imageUrl}" alt="${productName}">` : '<div>📦</div>'}
                        </div>
                        <div class="mobile-product-name">${productName}</div>
                    </div>
                `;
            });
        }
        
        html += '</div>';
        
        try {
            productsContainer.innerHTML = html;
            log('✅ Best seller products rendered successfully');
            return true;
        } catch (e) {
            logError('CRITICAL: Failed to set innerHTML', e);
            return false;
        }
        
    } catch (error) {
        logError('CRITICAL EXCEPTION in showBestSellerProducts()', error);
        return false;
    }
}

/**
 * SYSTEM FUNCTIONS
 */

function enableMobileViewDebugging() {
    MOBILE_VIEW_DEBUG.enabled = true;
    console.clear();
    
    console.log('%c╔════════════════════════════════════════════════════════════╗', 'color: #00cc00; font-weight: bold;');
    console.log('%c║          MOBILE VIEW DEBUGGING ENABLED                     ║', 'color: #00cc00; font-weight: bold;');
    console.log('%c╚════════════════════════════════════════════════════════════╝', 'color: #00cc00; font-weight: bold;');
    
    console.log('%cAvailable debug functions:', 'color: #0066cc; font-weight: bold;');
    console.log('  loadMobileCategorySections_DEBUG()   - Load sections with detailed logging');
    console.log('  showMobileCategoryProducts_DEBUG()   - Show category products with logging');
    console.log('  showMainCategoryCards_DEBUG()        - Show main categories with logging');
    console.log('  showBestSellerProducts_DEBUG()       - Show best sellers with logging');
    console.log('  getMobileViewDebugReport()           - Get debug report');
    console.log('  clearMobileViewDebugLogs()           - Clear debug logs');
    console.log('  testMobileViewFlow()                 - Run complete test flow');
    
    log('✅ Mobile view debugging initialized');
}

function disableMobileViewDebugging() {
    MOBILE_VIEW_DEBUG.enabled = false;
    log('❌ Mobile view debugging disabled');
}

function getMobileViewDebugReport() {
    console.clear();
    console.log('%c═══════════════════════════════════════════════════════════', 'color: #0066cc; font-weight: bold;');
    console.log('%c       MOBILE VIEW DEBUG REPORT', 'color: #0066cc; font-weight: bold; font-size: 14px;');
    console.log('%c═══════════════════════════════════════════════════════════', 'color: #0066cc; font-weight: bold;');
    
    // System state
    console.log('%c📊 SYSTEM STATE:', 'color: #0066cc; font-weight: bold;');
    console.log('  categoryHierarchy:', {
        defined: typeof categoryHierarchy !== 'undefined',
        length: categoryHierarchy?.length,
        sample: categoryHierarchy?.[0]
    });
    console.log('  categoryMetadata:', {
        defined: typeof categoryMetadata !== 'undefined',
        keys: Object.keys(categoryMetadata || {}).length,
        sample: Object.entries(categoryMetadata || {})[0]
    });
    console.log('  allProducts:', {
        defined: typeof allProducts !== 'undefined',
        length: allProducts?.length,
        bestSellerCount: allProducts?.filter(p => p.is_best_seller).length
    });
    
    // Container state
    console.log('%c🎯 CONTAINER STATE:', 'color: #0066cc; font-weight: bold;');
    const mobileSectionContainer = document.getElementById('mobileCategorySections');
    const mobileProductsContainer = document.getElementById('mobileProductsList');
    
    console.log('  #mobileCategorySections:', {
        exists: !!mobileSectionContainer,
        display: mobileSectionContainer ? window.getComputedStyle(mobileSectionContainer).display : 'N/A',
        visibility: mobileSectionContainer ? window.getComputedStyle(mobileSectionContainer).visibility : 'N/A',
        innerHTML: mobileSectionContainer ? `${mobileSectionContainer.innerHTML.length} chars` : 'N/A',
        childCount: mobileSectionContainer ? mobileSectionContainer.children.length : 'N/A'
    });
    
    console.log('  #mobileProductsList:', {
        exists: !!mobileProductsContainer,
        display: mobileProductsContainer ? window.getComputedStyle(mobileProductsContainer).display : 'N/A',
        visibility: mobileProductsContainer ? window.getComputedStyle(mobileProductsContainer).visibility : 'N/A',
        innerHTML: mobileProductsContainer ? `${mobileProductsContainer.innerHTML.length} chars` : 'N/A',
        childCount: mobileProductsContainer ? mobileProductsContainer.children.length : 'N/A'
    });
    
    // Debug logs
    console.log('%c📝 DEBUG LOGS (' + MOBILE_VIEW_DEBUG.logs.length + '):', 'color: #0066cc; font-weight: bold;');
    MOBILE_VIEW_DEBUG.logs.slice(-20).forEach(log => console.log('  ' + log));
    
    // Errors
    if (MOBILE_VIEW_DEBUG.errors.length > 0) {
        console.log('%c⚠️  ERRORS (' + MOBILE_VIEW_DEBUG.errors.length + '):', 'color: #ff0000; font-weight: bold;');
        MOBILE_VIEW_DEBUG.errors.forEach(err => console.log('  ' + err));
    }
    
    console.log('%c═══════════════════════════════════════════════════════════', 'color: #0066cc; font-weight: bold;');
}

function clearMobileViewDebugLogs() {
    MOBILE_VIEW_DEBUG.logs = [];
    MOBILE_VIEW_DEBUG.errors = [];
    log('✅ Debug logs cleared');
}

function testMobileViewFlow() {
    log('%c🧪 TESTING COMPLETE MOBILE VIEW FLOW', 'color: #00cc00; font-weight: bold; font-size: 14px;');
    
    setTimeout(() => {
        log('Test 1: Load categories...');
        loadMobileCategorySections_DEBUG();
    }, 500);
    
    setTimeout(() => {
        log('Test 2: Get first section...');
        if (categoryHierarchy && categoryHierarchy.length > 0) {
            const firstSection = categoryHierarchy[0].section;
            log(`Test 3: Show products for section: "${firstSection}"...`);
            showMobileCategoryProducts_DEBUG(firstSection);
        } else {
            logWarning('No categories to test');
        }
    }, 1500);
}

console.log('%c✅ Mobile View Debug Module Loaded', 'color: #00cc00; font-weight: bold; font-size: 12px;');
console.log('%cRun: enableMobileViewDebugging() to start', 'color: #0066cc; font-size: 11px;');
