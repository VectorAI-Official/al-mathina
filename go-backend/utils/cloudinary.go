package utils

import (
	"bytes"
	"context"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/cloudinary/cloudinary-go/v2"
	"github.com/cloudinary/cloudinary-go/v2/api/uploader"
)

var cloudinaryClient *cloudinary.Cloudinary

// InitCloudinary initializes the Cloudinary client
func InitCloudinary() error {
	cloudName := os.Getenv("CLOUDINARY_CLOUD_NAME")
	apiKey := os.Getenv("CLOUDINARY_API_KEY")
	apiSecret := os.Getenv("CLOUDINARY_API_SECRET")

	if cloudName == "" || apiKey == "" || apiSecret == "" {
		log.Println("⚠️  Cloudinary credentials not configured - image uploads will use local storage")
		return fmt.Errorf("cloudinary not configured")
	}

	cld, err := cloudinary.NewFromParams(cloudName, apiKey, apiSecret)
	if err != nil {
		return fmt.Errorf("failed to initialize Cloudinary: %w", err)
	}

	cloudinaryClient = cld
	log.Println("✓ Cloudinary initialized successfully")
	return nil
}

// IsCloudinaryReady checks if Cloudinary is configured
func IsCloudinaryReady() bool {
	return cloudinaryClient != nil
}

// UploadImage uploads an image to Cloudinary
func UploadImage(fileBytes []byte, filename string, folder string) (string, error) {
	if cloudinaryClient == nil {
		return "", fmt.Errorf("cloudinary not initialized")
	}

	ctx := context.Background()

	// Extract file extension and create public_id
	ext := filepath.Ext(filename)
	publicID := strings.TrimSuffix(filename, ext)

	// Upload parameters
	uploadParams := uploader.UploadParams{
		PublicID:     publicID,
		Folder:       folder,
		Overwrite:    boolPtr(true),
		ResourceType: "image",
	}

	// Upload to Cloudinary (SDK needs io.Reader, not []byte)
	reader := bytes.NewReader(fileBytes)
	result, err := cloudinaryClient.Upload.Upload(ctx, reader, uploadParams)
	if err != nil {
		return "", fmt.Errorf("cloudinary upload failed: %w", err)
	}

	log.Printf("✓ Image uploaded to Cloudinary: %s", result.SecureURL)
	return result.SecureURL, nil
}

// UploadCategoryImage uploads a category image with organized folder structure
func UploadCategoryImage(fileBytes []byte, filename string, categoryType string, categoryName string) (string, error) {
	folder := fmt.Sprintf("almathina/categories/%s", categoryType)

	// Create safe filename
	safeName := strings.ReplaceAll(categoryName, " ", "_")
	safeName = strings.ReplaceAll(safeName, "/", "-")
	ext := filepath.Ext(filename)
	customFilename := safeName + ext

	return UploadImage(fileBytes, customFilename, folder)
}

// UploadProductImage uploads a product image
func UploadProductImage(fileBytes []byte, filename string, productID string) (string, error) {
	folder := "almathina/products"
	ext := filepath.Ext(filename)
	customFilename := productID + ext

	return UploadImage(fileBytes, customFilename, folder)
}

// DeleteImage deletes an image from Cloudinary using its URL
// Extracts public_id from Cloudinary URL and calls Destroy API
func DeleteImage(imageURL string) bool {
	if cloudinaryClient == nil {
		fmt.Println("⚠️  Cloudinary not initialized - cannot delete image")
		return false
	}

	// Extract public_id from URL
	// Example: https://res.cloudinary.com/al-mathina/image/upload/v123/almathina/products/image.jpg
	// Public ID: almathina/products/image
	parts := strings.Split(imageURL, "/upload/")
	if len(parts) != 2 {
		fmt.Printf("⚠️  Invalid Cloudinary URL format: %s\n", imageURL)
		return false
	}

	// Remove version (v123456) if present
	publicIDPart := parts[1]
	if strings.Contains(publicIDPart, "/v") {
		versionParts := strings.Split(publicIDPart, "/v")
		publicIDPart = versionParts[0]
	}

	// Remove file extension
	publicID := publicIDPart
	if lastDot := strings.LastIndex(publicID, "."); lastDot != -1 {
		publicID = publicID[:lastDot]
	}

	// Call Cloudinary Destroy API
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	result, err := cloudinaryClient.Upload.Destroy(ctx, uploader.DestroyParams{
		PublicID: publicID,
	})

	if err != nil {
		fmt.Printf("✗ Failed to delete image from Cloudinary: %v\n", err)
		return false
	}

	if result.Result == "ok" {
		fmt.Printf("✓ Image deleted from Cloudinary: %s\n", publicID)
		return true
	}

	fmt.Printf("⚠️  Image deletion returned: %s\n", result.Result)
	return false
}

// Helper function to create bool pointer
func boolPtr(b bool) *bool {
	return &b
}
