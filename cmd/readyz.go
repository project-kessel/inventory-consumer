package cmd

import (
	"context"
	"crypto/tls"
	"crypto/x509"
	"fmt"
	"net"
	"os"
	"time"

	"github.com/go-kratos/kratos/v2/log"
	kessel "github.com/project-kessel/inventory-consumer/internal/client"
	inventoryv1 "github.com/project-kessel/kessel-sdk-go/kessel/inventory/v1"
	"github.com/spf13/cobra"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials"
	"google.golang.org/grpc/credentials/insecure"
)

const (
	InventoryGRPCPort = 9000
)

func readyzCommand(clientOptions *kessel.Options) *cobra.Command {
	readyzCmd := &cobra.Command{
		Use:   "readyz",
		Short: "Check if the Inventory API service is ready",
		Long: `Check if the Inventory API service is ready by making a gRPC request
to the kessel.inventory.v1.KesselInventoryHealthService.GetLivez endpoint.
The InventoryURL from the client configuration is used as the gRPC endpoint.
TLS configuration is applied based on the client options (insecure flag and CA cert file).
TLS is disabled by default but can be enabled if needed.`,
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

			// Parse the inventory URL to extract host
			host, _, err := net.SplitHostPort(clientOptions.InventoryURL)
			if err != nil {
				// If SplitHostPort fails, assume the URL is just a hostname
				log.Info("failed to split host port, assuming the URL is just a hostname", "url", clientOptions.InventoryURL)
				host = clientOptions.InventoryURL
			}

			// Build gRPC target address
			grpcTarget := fmt.Sprintf("%s:%d", host, InventoryGRPCPort)
			fmt.Printf("Checking inventory service readiness at: %s\n", grpcTarget)

			// Configure gRPC connection with TLS settings
			// TLS is disabled by default for readyz, but can be enabled if CACertFile is provided
			var dialOpts []grpc.DialOption
			var transportCreds credentials.TransportCredentials

			// Use insecure by default for readyz (TLS disabled on service by default)
			// If CACertFile is provided, that's an explicit request for TLS
			if clientOptions.CACertFile != "" {
				// TLS enabled via CA cert file
				caCert, err := os.ReadFile(clientOptions.CACertFile)
				if err != nil {
					return fmt.Errorf("failed to read CA certificate file %s: %w", clientOptions.CACertFile, err)
				}
				caCertPool := x509.NewCertPool()
				if !caCertPool.AppendCertsFromPEM(caCert) {
					return fmt.Errorf("failed to parse CA certificate from %s", clientOptions.CACertFile)
				}
				tlsConfig := &tls.Config{
					RootCAs: caCertPool,
				}
				transportCreds = credentials.NewTLS(tlsConfig)
			} else {
				// Default: insecure (TLS disabled)
				transportCreds = insecure.NewCredentials()
			}

			dialOpts = append(dialOpts, grpc.WithTransportCredentials(transportCreds))

			// Create gRPC connection with timeout
			ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
			defer cancel()

			conn, err := grpc.NewClient(grpcTarget, dialOpts...)
			if err != nil {
				return fmt.Errorf("failed to create gRPC client connection: %w", err)
			}
			defer conn.Close() //nolint:errcheck

			// Create health service client
			healthClient := inventoryv1.NewKesselInventoryHealthServiceClient(conn)

			// Call GetLivez
			req := &inventoryv1.GetLivezRequest{}
			resp, err := healthClient.GetLivez(ctx, req)
			if err != nil {
				return fmt.Errorf("failed to call GetLivez: %w", err)
			}

			// Check response
			if resp.Code >= 200 && resp.Code < 300 {
				fmt.Printf("Inventory service is ready! Code: %d, Status: %s\n", resp.Code, resp.Status)
				return nil
			} else {
				return fmt.Errorf("inventory service not ready. Code: %d, Status: %s", resp.Code, resp.Status)
			}
		},
	}

	clientOptions.AddFlags(readyzCmd.Flags(), "client")

	return readyzCmd
}
