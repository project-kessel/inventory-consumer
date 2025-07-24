package cmd

import (
	"fmt"
	"net/http"
	"strings"
	"time"

	kessel "github.com/project-kessel/inventory-consumer/internal/client"
	"github.com/project-kessel/inventory-consumer/internal/common"
	"github.com/spf13/cobra"
)

func readyzCommand(clientOptions *kessel.Options, loggerOptions common.LoggerOptions) *cobra.Command {
	readyzCmd := &cobra.Command{
		Use:   "readyz",
		Short: "Check if the Inventory API service is ready",
		Long: `Check if the Inventory API service is ready by making an HTTP request
to the InventoryURL + /api/inventory/v1/livez endpoint`,
		RunE: func(cmd *cobra.Command, args []string) error {
			// Initialize logger for potential debugging
			_, _ = common.InitLogger(common.GetLogLevel(), loggerOptions)

			// Validate client configuration
			if errs := clientOptions.Complete(); errs != nil {
				return fmt.Errorf("failed to setup client options: %v", errs)
			}
			if errs := clientOptions.Validate(); errs != nil {
				return fmt.Errorf("client options validation error: %v", errs)
			}

			// Check if client is enabled
			if !clientOptions.Enabled {
				return fmt.Errorf("inventory client is disabled")
			}

			// Check if InventoryURL is configured
			if clientOptions.InventoryURL == "" {
				return fmt.Errorf("inventory URL not configured")
			}

			// Construct the livez URL - convert gRPC URL to HTTP URL
			// The InventoryURL is typically a gRPC endpoint, but we need HTTP for the livez check
			inventoryURL := clientOptions.InventoryURL

			// Handle common gRPC port to HTTP port conversion
			// If the URL contains port 9000 (common gRPC port), try 8000 for HTTP
			if strings.Contains(inventoryURL, ":9000") {
				inventoryURL = strings.Replace(inventoryURL, ":9000", ":8000", 1)
			}

			// Ensure http:// prefix if not present and insecure is true
			if !strings.HasPrefix(inventoryURL, "http://") && !strings.HasPrefix(inventoryURL, "https://") {
				if clientOptions.Insecure {
					inventoryURL = "http://" + inventoryURL
				} else {
					inventoryURL = "https://" + inventoryURL
				}
			}

			livezURL := inventoryURL + "/api/inventory/v1/livez"

			fmt.Printf("Checking inventory service readiness at: %s\n", livezURL)

			// Create HTTP client with timeout
			client := &http.Client{
				Timeout: 10 * time.Second,
			}

			// Make HTTP GET request to livez endpoint
			resp, err := client.Get(livezURL)
			if err != nil {
				return fmt.Errorf("failed to check inventory service health: %v", err)
			}
			defer resp.Body.Close()

			// Check if the response indicates the service is healthy
			if resp.StatusCode != http.StatusOK {
				return fmt.Errorf("inventory service not healthy, status: %d", resp.StatusCode)
			}

			// Return success
			fmt.Println("Inventory service is ready!")
			return nil
		},
	}

	// Add client flags to the readyz command
	clientOptions.AddFlags(readyzCmd.Flags(), "client")

	return readyzCmd
}
