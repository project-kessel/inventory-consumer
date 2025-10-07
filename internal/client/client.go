package kessel

import (
	"context"
	"fmt"

	"github.com/go-kratos/kratos/v2/log"
	"github.com/project-kessel/kessel-sdk-go/kessel/auth"
	kesselgrpc "github.com/project-kessel/kessel-sdk-go/kessel/grpc"
	"github.com/project-kessel/kessel-sdk-go/kessel/inventory/v1beta2"
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
}

func New(c CompletedConfig, logger *log.Helper) (*KesselClient, error) {
	logger.Info("Setting up Inventory API client")
	var client v1beta2.KesselInventoryServiceClient
	var err error

	if !c.Enabled {
		logger.Info("ClientProvider enabled: ", c.Enabled)
		return &KesselClient{Enabled: false}, nil
	}

	if c.EnableOidcAuth {
		oauthCredentials := auth.NewOAuth2ClientCredentials(c.ClientId, c.ClientSecret, c.TokenEndpoint)
		// TODO: Build can return a grpc.ClientConn for closing the connection
		// need to investigate where this could be implemented, security/performance, etc
		if c.Insecure {
			client, _, err = v1beta2.NewClientBuilder(c.InventoryURL).
				Authenticated(kesselgrpc.OAuth2CallCredentials(&oauthCredentials), nil).Insecure().Build()
		} else {
			client, _, err = v1beta2.NewClientBuilder(c.InventoryURL).
				Authenticated(kesselgrpc.OAuth2CallCredentials(&oauthCredentials), nil).Build()
		}
		if err != nil {
			return &KesselClient{}, fmt.Errorf("failed to create gRPC client: %w", err)
		}
	} else {
		if c.Insecure {
			client, _, err = v1beta2.NewClientBuilder(c.InventoryURL).Insecure().Build()
		} else {
			client, _, err = v1beta2.NewClientBuilder(c.InventoryURL).Build()
		}
		if err != nil {
			return &KesselClient{}, fmt.Errorf("failed to create gRPC client: %w", err)
		}
	}
	return &KesselClient{
		KesselInventoryServiceClient: client,
		Enabled:                      c.Enabled,
		AuthEnabled:                  c.EnableOidcAuth,
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
