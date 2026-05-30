// ============================================
// IMAGE CONVERTER FUNCTIONS
// ============================================

let originalImageFile = null;
let originalImageData = null;
let convertedBlob = null;
let inlineConverterCallback = null;
let currentInlineContainerId = null;

// Open Image Converter Modal
function openImageConverterModal() {
    const modal = document.getElementById('imageConverterModal');
    modal.style.display = 'block';
    resetImageConverter();
}

// Open inline converter (for Add/Edit forms)
function openInlineConverter(containerId, callback, defaultQuality = 100) {
    currentInlineContainerId = containerId;
    inlineConverterCallback = callback;
    
    const container = document.getElementById(containerId);
    if (!container) {
        console.error('Container not found:', containerId);
        return;
    }
    
    container.innerHTML = 
        '<div class="inline-converter-wrapper">' +
            '<div class="inline-converter-header">' +
                '<h4 style="margin: 0; color: #7B1FA2;">🖼️ Image Converter</h4>' +
                '<button type="button" class="btn-sm" onclick="closeInlineConverter()" style="padding: 4px 12px;">✕ Close</button>' +
            '</div>' +
            '<div class="inline-converter-content">' +
                '<div class="file-upload-area" id="inlineConverterUploadArea" onclick="document.getElementById(\'inlineConverterFileInput\').click()">' +
                    '<div class="upload-icon">📁</div>' +
                    '<div class="upload-text">Click to select image</div>' +
                    '<div class="upload-hint">JPG, PNG, WEBP (any size)</div>' +
                '</div>' +
                '<input type="file" id="inlineConverterFileInput" accept="image/jpeg,image/jpg,image/png,image/webp" style="display: none;" onchange="handleInlineConverterImageUpload(event)">' +
                '<div class="converter-preview-grid" id="inlineConverterPreviewGrid" style="display: none;">' +
                    '<div class="preview-box">' +
                        '<div class="preview-label">Original Image</div>' +
                        '<div class="preview-container" id="inlineOriginalPreviewContainer"></div>' +
                        '<div class="preview-info" id="inlineOriginalImageInfo"></div>' +
                    '</div>' +
                    '<div class="preview-box">' +
                        '<div class="preview-label">Converted (400×400)</div>' +
                        '<div class="preview-container" id="inlineConvertedPreviewContainer"></div>' +
                        '<div class="preview-info" id="inlineConvertedImageInfo"></div>' +
                    '</div>' +
                '</div>' +
                '<div class="converter-settings" id="inlineConverterSettings" style="display: none;">' +
                    '<label for="inlineQualitySlider" style="font-weight: 600; margin-bottom: 8px; display: block;">Quality: <span id="inlineQualityValue">' + defaultQuality + '</span>%</label>' +
                    '<input type="range" id="inlineQualitySlider" min="60" max="100" value="' + defaultQuality + '" onchange="updateInlineQualityValue(this.value); reconvertInlineImage();" style="width: 100%;">' +
                    '<div style="display: flex; justify-content: space-between; font-size: 11px; color: #666; margin-top: 4px;">' +
                        '<span>More Compression</span>' +
                        '<span>Better Quality</span>' +
                    '</div>' +
                '</div>' +
                '<div class="inline-converter-actions" id="inlineConverterActions" style="display: none; margin-top: 16px;">' +
                    '<button type="button" class="btn-primary" onclick="useInlineConvertedImage()" style="width: 100%;">✓ Use Image</button>' +
                '</div>' +
            '</div>' +
        '</div>';
    
    container.style.display = 'block';
}

// Close inline converter
function closeInlineConverter() {
    if (currentInlineContainerId) {
        const container = document.getElementById(currentInlineContainerId);
        if (container) {
            container.innerHTML = '';
            container.style.display = 'none';
        }
    }
    
    originalImageFile = null;
    originalImageData = null;
    convertedBlob = null;
    inlineConverterCallback = null;
    currentInlineContainerId = null;
}

// Close Image Converter Modal
function closeImageConverterModal() {
    const modal = document.getElementById('imageConverterModal');
    modal.style.display = 'none';
    resetImageConverter();
}

// Reset converter state
function resetImageConverter() {
    originalImageFile = null;
    originalImageData = null;
    convertedBlob = null;
    
    // Reset upload area
    const uploadArea = document.getElementById('converterUploadArea');
    if (uploadArea) {
        uploadArea.innerHTML = '<div class="upload-icon">📁</div><div class="upload-text">Click to select image</div><div class="upload-hint">JPG, PNG, WEBP (any size)</div>';
    }
    
    // Reset previews
    const originalPreview = document.getElementById('originalPreviewContainer');
    if (originalPreview) {
        originalPreview.innerHTML = '<div class="preview-placeholder"><div class="placeholder-icon">🖼️</div><div class="placeholder-text">No image uploaded</div></div>';
    }
    
    const convertedPreview = document.getElementById('convertedPreviewContainer');
    if (convertedPreview) {
        convertedPreview.innerHTML = '<div class="preview-placeholder"><div class="placeholder-icon">✨</div><div class="placeholder-text">Conversion result will appear here</div></div>';
    }
    
    // Clear info
    const originalInfo = document.getElementById('originalImageInfo');
    if (originalInfo) originalInfo.innerHTML = '';
    
    const convertedInfo = document.getElementById('convertedImageInfo');
    if (convertedInfo) convertedInfo.innerHTML = '';
    
    // Hide settings and actions
    const settings = document.getElementById('converterSettings');
    if (settings) settings.style.display = 'none';
    
    const actions = document.getElementById('converterActions');
    if (actions) actions.style.display = 'none';
    
    // Reset quality slider
    const slider = document.getElementById('qualitySlider');
    if (slider) slider.value = 85;
    
    const qualityValue = document.getElementById('qualityValue');
    if (qualityValue) qualityValue.textContent = '85';
}

// Handle image upload
function handleConverterImageUpload(event) {
    const file = event.target.files[0];
    if (!file) return;
    
    // Validate file type
    const allowedTypes = ['image/jpeg', 'image/jpg', 'image/png', 'image/webp'];
    if (!allowedTypes.includes(file.type)) {
        showToast('Invalid file type. Please use JPG, PNG, or WEBP', 'error');
        return;
    }
    
    originalImageFile = file;
    
    // Read and display original image
    const reader = new FileReader();
    reader.onload = function(e) {
        originalImageData = e.target.result;
        displayOriginalImage(e.target.result, file);
        convertImage();
    };
    reader.readAsDataURL(file);
    
    // Update upload area
    const uploadArea = document.getElementById('converterUploadArea');
    if (uploadArea) {
        uploadArea.innerHTML = '<div class="upload-icon">✅</div><div class="upload-text" style="color: #4CAF50;">Image uploaded successfully!</div><div class="upload-hint">Click to change image</div>';
    }
}

// Display original image
function displayOriginalImage(dataUrl, file) {
    const img = new Image();
    img.onload = function() {
        const container = document.getElementById('originalPreviewContainer');
        if (container) {
            container.innerHTML = '<img src="' + dataUrl + '" alt="Original">';
        }
        
        const sizeInMB = (file.size / (1024 * 1024)).toFixed(2);
        const sizeClass = file.size > 1024 * 1024 ? 'info-warning' : 'info-success';
        
        const infoDiv = document.getElementById('originalImageInfo');
        if (infoDiv) {
            infoDiv.innerHTML = '<div><span class="info-label">Dimensions:</span> ' + img.width + ' × ' + img.height + ' px</div>' +
                '<div><span class="info-label">File Size:</span> <span class="' + sizeClass + '">' + sizeInMB + ' MB</span></div>' +
                '<div><span class="info-label">Format:</span> ' + file.type.split('/')[1].toUpperCase() + '</div>';
        }
    };
    img.src = dataUrl;
}

// Convert image to 400x400
function convertImage() {
    const img = new Image();
    img.onload = function() {
        // Create canvas
        const canvas = document.createElement('canvas');
        const ctx = canvas.getContext('2d');
        
        // Set canvas size to 400x400
        canvas.width = 400;
        canvas.height = 400;
        
        // Calculate crop dimensions to maintain aspect ratio and center
        const sourceSize = Math.min(img.width, img.height);
        const sourceX = (img.width - sourceSize) / 2;
        const sourceY = (img.height - sourceSize) / 2;
        
        // Draw image (cropped and centered)
        ctx.drawImage(
            img,
            sourceX, sourceY, sourceSize, sourceSize,
            0, 0, 400, 400
        );
        
        // Get quality value
        const qualitySlider = document.getElementById('qualitySlider');
        const quality = qualitySlider ? parseInt(qualitySlider.value) / 100 : 0.85;
        
        // Convert to blob
        canvas.toBlob(function(blob) {
            convertedBlob = blob;
            displayConvertedImage(canvas.toDataURL('image/jpeg', quality), blob);
            
            // Show settings and actions
            const settings = document.getElementById('converterSettings');
            if (settings) settings.style.display = 'block';
            
            const actions = document.getElementById('converterActions');
            if (actions) actions.style.display = 'flex';
            
            showToast('✅ Image converted successfully!', 'success');
        }, 'image/jpeg', quality);
    };
    img.src = originalImageData;
}

// Display converted image
function displayConvertedImage(dataUrl, blob) {
    const container = document.getElementById('convertedPreviewContainer');
    if (container) {
        container.innerHTML = '<img src="' + dataUrl + '" alt="Converted">';
    }
    
    const sizeInMB = (blob.size / (1024 * 1024)).toFixed(2);
    const sizeClass = blob.size > 1024 * 1024 ? 'info-warning' : 'info-success';
    
    const infoDiv = document.getElementById('convertedImageInfo');
    if (infoDiv) {
        const message = blob.size > 1024 * 1024 
            ? '⚠️ File size > 1MB. Reduce quality to compress further.' 
            : '✅ File size is optimized!';
        
        infoDiv.innerHTML = '<div><span class="info-label">Dimensions:</span> 400 × 400 px</div>' +
            '<div><span class="info-label">File Size:</span> <span class="' + sizeClass + '">' + sizeInMB + ' MB</span></div>' +
            '<div><span class="info-label">Format:</span> JPEG</div>' +
            '<div style="margin-top: 8px; font-size: 12px;">' + message + '</div>';
    }
}

// Update quality value display
function updateQualityValue(value) {
    const qualityValue = document.getElementById('qualityValue');
    if (qualityValue) qualityValue.textContent = value;
}

// Reconvert with new quality
function reconvertImage() {
    if (!originalImageData) return;
    convertImage();
}

// Download converted image
function downloadConvertedImage() {
    if (!convertedBlob) {
        showToast('No converted image to download', 'error');
        return;
    }
    
    // Create download link
    const url = URL.createObjectURL(convertedBlob);
    const a = document.createElement('a');
    a.href = url;
    
    // Generate filename
    const originalName = originalImageFile ? originalImageFile.name : 'image';
    const baseName = originalName.replace(/\.[^/.]+$/, '');
    a.download = baseName + '_400x400.jpg';
    
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
    
    showToast('✅ Image downloaded successfully!', 'success');
}

// ============================================
// INLINE CONVERTER FUNCTIONS
// ============================================

// Handle inline converter image upload
function handleInlineConverterImageUpload(event) {
    const file = event.target.files[0];
    if (!file) return;
    
    // Validate file type
    const allowedTypes = ['image/jpeg', 'image/jpg', 'image/png', 'image/webp'];
    if (!allowedTypes.includes(file.type)) {
        showToast('Invalid file type. Please use JPG, PNG, or WEBP', 'error');
        return;
    }
    
    originalImageFile = file;
    
    // Read and display original image
    const reader = new FileReader();
    reader.onload = function(e) {
        originalImageData = e.target.result;
        displayInlineOriginalImage(e.target.result, file);
        convertInlineImage();
    };
    reader.readAsDataURL(file);
    
    // Update upload area
    const uploadArea = document.getElementById('inlineConverterUploadArea');
    if (uploadArea) {
        uploadArea.innerHTML = '<div class="upload-icon">✅</div><div class="upload-text" style="color: #4CAF50;">Image uploaded successfully!</div><div class="upload-hint">Click to change image</div>';
    }
    
    // Show preview grid
    const previewGrid = document.getElementById('inlineConverterPreviewGrid');
    if (previewGrid) previewGrid.style.display = 'grid';
}

// Display inline original image
function displayInlineOriginalImage(dataUrl, file) {
    const img = new Image();
    img.onload = function() {
        const container = document.getElementById('inlineOriginalPreviewContainer');
        if (container) {
            container.innerHTML = '<img src="' + dataUrl + '" alt="Original" style="max-width: 100%; max-height: 100%; object-fit: contain;">';
        }
        
        const sizeInMB = (file.size / (1024 * 1024)).toFixed(2);
        const sizeClass = file.size > 1024 * 1024 ? 'info-warning' : 'info-success';
        
        const infoDiv = document.getElementById('inlineOriginalImageInfo');
        if (infoDiv) {
            infoDiv.innerHTML = '<div><span class="info-label">Dimensions:</span> ' + img.width + ' × ' + img.height + ' px</div>' +
                '<div><span class="info-label">File Size:</span> <span class="' + sizeClass + '">' + sizeInMB + ' MB</span></div>' +
                '<div><span class="info-label">Format:</span> ' + file.type.split('/')[1].toUpperCase() + '</div>';
        }
    };
    img.src = dataUrl;
}

// Convert inline image to 400x400
function convertInlineImage() {
    const img = new Image();
    img.onload = function() {
        // Create canvas
        const canvas = document.createElement('canvas');
        const ctx = canvas.getContext('2d');
        
        // Set canvas size to 400x400
        canvas.width = 400;
        canvas.height = 400;
        
        // Calculate crop dimensions to maintain aspect ratio and center
        const sourceSize = Math.min(img.width, img.height);
        const sourceX = (img.width - sourceSize) / 2;
        const sourceY = (img.height - sourceSize) / 2;
        
        // Draw image (cropped and centered)
        ctx.drawImage(
            img,
            sourceX, sourceY, sourceSize, sourceSize,
            0, 0, 400, 400
        );
        
        // Get quality value
        const qualitySlider = document.getElementById('inlineQualitySlider');
        const quality = qualitySlider ? parseInt(qualitySlider.value) / 100 : 1.0;
        
        // Convert to blob
        canvas.toBlob(function(blob) {
            convertedBlob = blob;
            displayInlineConvertedImage(canvas.toDataURL('image/jpeg', quality), blob);
            
            // Show settings and actions
            const settings = document.getElementById('inlineConverterSettings');
            if (settings) settings.style.display = 'block';
            
            const actions = document.getElementById('inlineConverterActions');
            if (actions) actions.style.display = 'block';
            
            showToast('✅ Image converted to 400×400 at ' + Math.round(quality * 100) + '% quality!', 'success');
        }, 'image/jpeg', quality);
    };
    img.src = originalImageData;
}

// Display inline converted image
function displayInlineConvertedImage(dataUrl, blob) {
    const container = document.getElementById('inlineConvertedPreviewContainer');
    if (container) {
        container.innerHTML = '<img src="' + dataUrl + '" alt="Converted" style="max-width: 100%; max-height: 100%; object-fit: contain;">';
    }
    
    const sizeInMB = (blob.size / (1024 * 1024)).toFixed(2);
    const sizeClass = blob.size > 1024 * 1024 ? 'info-warning' : 'info-success';
    
    const infoDiv = document.getElementById('inlineConvertedImageInfo');
    if (infoDiv) {
        const message = blob.size > 1024 * 1024 
            ? '⚠️ File size > 1MB. Reduce quality to compress further.' 
            : '✅ File size is optimized!';
        
        infoDiv.innerHTML = '<div><span class="info-label">Dimensions:</span> 400 × 400 px</div>' +
            '<div><span class="info-label">File Size:</span> <span class="' + sizeClass + '">' + sizeInMB + ' MB</span></div>' +
            '<div><span class="info-label">Format:</span> JPEG</div>' +
            '<div style="margin-top: 8px; font-size: 12px;">' + message + '</div>';
    }
}

// Update inline quality value display
function updateInlineQualityValue(value) {
    const qualityValue = document.getElementById('inlineQualityValue');
    if (qualityValue) qualityValue.textContent = value;
}

// Reconvert inline image with new quality
function reconvertInlineImage() {
    if (!originalImageData) return;
    convertInlineImage();
}

// Use converted image (call callback)
function useInlineConvertedImage() {
    if (!convertedBlob) {
        showToast('No converted image available', 'error');
        return;
    }
    
    if (inlineConverterCallback && typeof inlineConverterCallback === 'function') {
        // Create a File object from the blob with proper naming
        const originalName = originalImageFile ? originalImageFile.name : 'image.jpg';
        const baseName = originalName.replace(/\.[^/.]+$/, '');
        const convertedFile = new File([convertedBlob], baseName + '_400x400.jpg', {
            type: 'image/jpeg',
            lastModified: Date.now()
        });
        
        inlineConverterCallback(convertedFile, convertedBlob);
        showToast('✅ Image ready to upload!', 'success');
        closeInlineConverter();
    } else {
        showToast('No callback function defined', 'error');
    }
}

// Close modal when clicking outside
window.onclick = function(event) {
    const modal = document.getElementById('imageConverterModal');
    if (event.target === modal) {
        closeImageConverterModal();
    }
};
