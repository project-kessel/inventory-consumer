package cmd

import (
	"context"
	"crypto/tls"
	"crypto/x509"
	"fmt"
	"io"
	"net"
	"net/http"
	"os"
	"time"

	"github.com/go-kratos/kratos/v2/log"
	kessel "github.com/project-kessel/inventory-consumer/internal/client"
	"github.com/spf13/cobra"
)

const (
	InventoryLiveZHTTPEndpoint = "/api/inventory/v1/livez"
	InventoryHTTPPort          = 8000
	InventoryHTTPTLSPort       = 8800
)

func readyzCommand(clientOptions *kessel.Options) *cobra.Command {
	readyzCmd := &cobra.Command{
		Use:   "readyz",
		Short: "Check if the Inventory API service is ready",
		Long: `Check if the Inventory API service is ready by making an HTTP request
to the /api/inventory/v1/livez endpoint.
The InventoryURL from the client configuration is used as the HTTP endpoint.
TLS configuration is applied based on the client options (insecure flag and CA cert file).`,
		SilenceUsage:  true,
		SilenceErrors: true,
		RunE: func(cmd *cobra.Command, args []string) error {
			// Validate client configuration
			if errs := clientOptions.Complete(); errs != nil {
				return fmt.Errorf("failed to setup client options")
			}
			if errs := clientOptions.Validate(); errs != nil {
				return fmt.Errorf("client options validation error")
			}

			// Check if client is enabled
			if !clientOptions.Enabled {
				log.Info("inventory service is not enabled")
				return nil
			}

			host, _, err := net.SplitHostPort(clientOptions.InventoryURL)
			if err != nil {
				return fmt.Errorf("failed to parse inventory URL: %w", err)
			}

			var inventoryURL string
			fmt.Printf("Checking inventory service readiness at: %s\n", clientOptions.InventoryURL)

			if clientOptions.Insecure {
				inventoryURL = fmt.Sprintf("%s:%d%s", host, InventoryHTTPPort, InventoryLiveZHTTPEndpoint)
			} else {
				inventoryURL = fmt.Sprintf("%s:%d%s", host, InventoryHTTPTLSPort, InventoryLiveZHTTPEndpoint)
			}

			// Create HTTP client with appropriate TLS configuration
			httpClient := &http.Client{
				Timeout: 30 * time.Second,
			}

			if !clientOptions.Insecure {
				// Configure TLS with CA certificate
				tlsConfig := &tls.Config{}

				if clientOptions.CACertFile != "" {
					// Load CA certificate
					caCert, err := os.ReadFile(clientOptions.CACertFile)
					if err != nil {
						return fmt.Errorf("failed to read CA certificate file %s: %w", clientOptions.CACertFile, err)
					}

					caCertPool := x509.NewCertPool()
					if !caCertPool.AppendCertsFromPEM(caCert) {
						return fmt.Errorf("failed to parse CA certificate from %s", clientOptions.CACertFile)
					}

					tlsConfig.RootCAs = caCertPool
				}

				// Create transport with TLS configuration
				transport := &http.Transport{
					TLSClientConfig: tlsConfig,
				}
				httpClient.Transport = transport
			}

			// Make HTTP request
			req, err := http.NewRequestWithContext(context.Background(), "GET", inventoryURL, nil)
			if err != nil {
				return fmt.Errorf("failed to create HTTP request: %w", err)
			}

			resp, err := httpClient.Do(req)
			if err != nil {
				return fmt.Errorf("failed to make HTTP request to %s: %w", inventoryURL, err)
			}
			defer resp.Body.Close()

			// Read response body
			body, err := io.ReadAll(resp.Body)
			if err != nil {
				return fmt.Errorf("failed to read response body: %w", err)
			}

			// Check response status
			if resp.StatusCode >= 200 && resp.StatusCode < 300 {
				fmt.Printf("Inventory service is ready! Status: %d, Response: %s\n", resp.StatusCode, string(body))
				return nil
			} else {
				return fmt.Errorf("inventory service not ready. Status: %d, Response: %s", resp.StatusCode, string(body))
			}
		},
	}

	// Add client flags to the readyz command
	clientOptions.AddFlags(readyzCmd.Flags(), "client")

	return readyzCmd
}
