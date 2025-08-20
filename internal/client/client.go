package kessel

import (
	"context"
	"fmt"

	"github.com/go-kratos/kratos/v2/log"
	"github.com/project-kessel/kessel-sdk-go/kessel/auth"
	"github.com/project-kessel/kessel-sdk-go/kessel/inventory/v1beta2"
	"google.golang.org/grpc"
)

type ClientProvider interface {
	CreateOrUpdateResource(request *v1beta2.ReportResourceRequest) (*v1beta2.ReportResourceResponse, error)
	DeleteResource(request *v1beta2.DeleteResourceRequest) (*v1beta2.DeleteResourceResponse, error)
	IsEnabled() bool
}

type KesselClient struct {
	v1beta2.KesselInventoryServiceClient
	Enabled     bool
	AuthEnabled bool
	conn        *grpc.ClientConn
}

func New(c CompletedConfig, logger *log.Helper) (*KesselClient, error) {
	logger.Info("Setting up Inventory API client")
	var client v1beta2.KesselInventoryServiceClient
	var conn *grpc.ClientConn
	var err error

	if !c.Enabled {
		logger.Info("ClientProvider enabled: ", c.Enabled)
		return &KesselClient{Enabled: false}, nil
	}

	if c.EnableOidcAuth {
		oauthCredentials := auth.NewOAuth2ClientCredentials(c.ClientId, c.ClientSecret, c.TokenEndpoint)
		client, conn, err = v1beta2.NewClientBuilder(c.InventoryURL).
			OAuth2ClientAuthenticated(&oauthCredentials, nil).
			Build()
	} else {
		client, conn, err = v1beta2.NewClientBuilder(c.InventoryURL).
			Insecure().
			Build()
	}
	if err != nil {
		return &KesselClient{}, fmt.Errorf("failed to create Inventory API gRPC client: %w", err)
	}
	return &KesselClient{
		KesselInventoryServiceClient: client,
		Enabled:                      c.Enabled,
		AuthEnabled:                  c.EnableOidcAuth,
		conn:                         conn,
	}, nil
}

func (k *KesselClient) CreateOrUpdateResource(request *v1beta2.ReportResourceRequest) (*v1beta2.ReportResourceResponse, error) {
	resp, err := k.ReportResource(context.Background(), request)
	if err != nil {
		return nil, fmt.Errorf("failed to report resource: %w", err)
	}
	return resp, nil
}

func (k *KesselClient) DeleteResource(request *v1beta2.DeleteResourceRequest) (*v1beta2.DeleteResourceResponse, error) {
	resp, err := k.KesselInventoryServiceClient.DeleteResource(context.Background(), request)
	if err != nil {
		return nil, fmt.Errorf("failed to delete resource: %w", err)
	}
	return resp, nil
}

func (k *KesselClient) IsEnabled() bool {
	return k.Enabled
}

// Close gracefully closes the underlying gRPC connection.
func (k *KesselClient) Close() error {
	if k == nil || k.conn == nil {
		return nil
	}
	return k.conn.Close()
}
