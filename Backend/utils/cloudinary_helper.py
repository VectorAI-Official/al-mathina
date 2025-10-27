"""
Cloudinary Integration for Image Storage
Handles image uploads, URL generation, and deletion
"""
import cloudinary
import cloudinary.uploader
import cloudinary.api
from typing import Optional, Dict, Any
import logging
from pathlib import Path
import os

try:
    from config_production import settings
    IS_PRODUCTION = True
except ImportError:
    try:
        from config_local import settings
        IS_PRODUCTION = False
    except ImportError:
        from config import settings
        IS_PRODUCTION = False

logger = logging.getLogger(__name__)


class CloudinaryManager:
    """Manages Cloudinary operations for image storage"""
    
    def __init__(self):
        """Initialize Cloudinary configuration"""
        self._initialized = False
        self._setup_cloudinary()
    
    def _setup_cloudinary(self):
        """Setup Cloudinary with credentials"""
        try:
            if hasattr(settings, 'cloudinary_cloud_name'):
                cloudinary.config(
                    cloud_name=settings.cloudinary_cloud_name,
                    api_key=settings.cloudinary_api_key,
                    api_secret=settings.cloudinary_api_secret,
                    secure=True
                )
                self._initialized = True
                logger.info("✓ Cloudinary initialized successfully")
            else:
                logger.warning("⚠ Cloudinary credentials not found - image uploads will fail")
                self._initialized = False
        except Exception as e:
            logger.error(f"✗ Failed to initialize Cloudinary: {e}")
            self._initialized = False
    
    def is_ready(self) -> bool:
        """Check if Cloudinary is properly configured"""
        return self._initialized
    
    def upload_image(
        self,
        file_content: bytes,
        filename: str,
        folder: str = "almathina",
        resource_type: str = "image"
    ) -> Optional[Dict[str, Any]]:
        """
        Upload an image to Cloudinary
        
        Args:
            file_content: Image file content as bytes
            filename: Original filename
            folder: Cloudinary folder to organize images
            resource_type: Type of resource (image, video, etc.)
        
        Returns:
            Dictionary with upload result including secure_url, public_id, etc.
        """
        if not self._initialized:
            logger.error("Cloudinary not initialized - cannot upload image")
            return None
        
        try:
            # Extract file extension
            file_ext = Path(filename).suffix.lower()
            # Don't include folder in public_id - it's already specified in folder parameter
            public_id = Path(filename).stem
            
            # Upload to Cloudinary
            result = cloudinary.uploader.upload(
                file_content,
                public_id=public_id,
                resource_type=resource_type,
                folder=folder,
                overwrite=True,
                format=file_ext.lstrip('.'),  # Force specific format
                flags='progressive',  # Make it progressive for web
                # No transformations - preserve original file exactly
                transformation=None
            )
            
            logger.info(f"✓ Image uploaded successfully: {result['secure_url']}")
            return result
        
        except Exception as e:
            logger.error(f"✗ Failed to upload image to Cloudinary: {e}")
            return None
    
    def upload_category_image(
        self,
        file_content: bytes,
        filename: str,
        category_type: str,
        category_name: str
    ) -> Optional[str]:
        """
        Upload a category image to Cloudinary
        
        Args:
            file_content: Image file content
            filename: Original filename
            category_type: Type of category (section, main_category, subcategory, product)
            category_name: Name of the category
        
        Returns:
            Secure URL of the uploaded image
        """
        folder = f"almathina/categories/{category_type}"
        safe_name = category_name.replace(" ", "_").replace("/", "-")
        file_ext = Path(filename).suffix
        custom_filename = f"{safe_name}{file_ext}"
        
        result = self.upload_image(file_content, custom_filename, folder=folder)
        return result['secure_url'] if result else None
    
    def upload_product_image(
        self,
        file_content: bytes,
        filename: str,
        product_id: str
    ) -> Optional[str]:
        """
        Upload a product image to Cloudinary
        
        Args:
            file_content: Image file content
            filename: Original filename
            product_id: Product ID
        
        Returns:
            Secure URL of the uploaded image
        """
        folder = "almathina/products"
        file_ext = Path(filename).suffix
        custom_filename = f"{product_id}{file_ext}"
        
        result = self.upload_image(file_content, custom_filename, folder=folder)
        return result['secure_url'] if result else None
    
    def delete_image(self, public_id: str) -> bool:
        """
        Delete an image from Cloudinary
        
        Args:
            public_id: Cloudinary public ID of the image
        
        Returns:
            True if deleted successfully, False otherwise
        """
        if not self._initialized:
            logger.error("Cloudinary not initialized - cannot delete image")
            return False
        
        try:
            result = cloudinary.uploader.destroy(public_id)
            if result.get('result') == 'ok':
                logger.info(f"✓ Image deleted successfully: {public_id}")
                return True
            else:
                logger.warning(f"⚠ Image deletion returned: {result}")
                return False
        except Exception as e:
            logger.error(f"✗ Failed to delete image from Cloudinary: {e}")
            return False
    
    def get_image_url(self, public_id: str, transformations: Optional[Dict] = None) -> Optional[str]:
        """
        Generate a Cloudinary URL for an image with optional transformations
        
        Args:
            public_id: Cloudinary public ID
            transformations: Optional transformations (width, height, crop, etc.)
        
        Returns:
            Secure URL of the image
        """
        if not self._initialized:
            return None
        
        try:
            if transformations:
                url, options = cloudinary.utils.cloudinary_url(
                    public_id,
                    **transformations,
                    secure=True
                )
                return url
            else:
                return cloudinary.CloudinaryImage(public_id).build_url(secure=True)
        except Exception as e:
            logger.error(f"✗ Failed to generate image URL: {e}")
            return None


# Singleton instance
_cloudinary_manager: Optional[CloudinaryManager] = None


def get_cloudinary_manager() -> CloudinaryManager:
    """Get or create CloudinaryManager instance"""
    global _cloudinary_manager
    if _cloudinary_manager is None:
        _cloudinary_manager = CloudinaryManager()
    return _cloudinary_manager


def upload_image_to_cloudinary(
    file_content: bytes,
    filename: str,
    category_type: str = None,
    category_name: str = None,
    product_id: str = None
) -> Optional[str]:
    """
    Convenience function to upload an image
    
    Args:
        file_content: Image file content
        filename: Original filename
        category_type: Type of category (for category images)
        category_name: Name of category (for category images)
        product_id: Product ID (for product images)
    
    Returns:
        Secure URL of uploaded image
    """
    manager = get_cloudinary_manager()
    
    if not manager.is_ready():
        logger.error("Cloudinary not configured - cannot upload image")
        return None
    
    if product_id:
        return manager.upload_product_image(file_content, filename, product_id)
    elif category_type and category_name:
        return manager.upload_category_image(file_content, filename, category_type, category_name)
    else:
        result = manager.upload_image(file_content, filename)
        return result['secure_url'] if result else None


def delete_image_from_cloudinary(image_url: str) -> bool:
    """
    Delete an image from Cloudinary using its URL
    
    Args:
        image_url: Full Cloudinary URL
    
    Returns:
        True if deleted successfully
    """
    manager = get_cloudinary_manager()
    
    if not manager.is_ready():
        return False
    
    # Extract public_id from URL
    # Example: https://res.cloudinary.com/vectorai/image/upload/v123/almathina/categories/section/image.jpg
    try:
        parts = image_url.split('/upload/')
        if len(parts) == 2:
            # Remove version and file extension
            public_id = parts[1].split('/v')[0] if '/v' in parts[1] else parts[1]
            public_id = public_id.rsplit('.', 1)[0]  # Remove extension
            return manager.delete_image(public_id)
    except Exception as e:
        logger.error(f"Failed to extract public_id from URL: {e}")
    
    return False
