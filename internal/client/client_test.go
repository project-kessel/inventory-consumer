package kessel

import (
	"crypto/rand"
	"crypto/rsa"
	"crypto/x509"
	"crypto/x509/pkix"
	"encoding/pem"
	"errors"
	"fmt"
	"math/big"
	"testing"
	"time"

	"github.com/go-kratos/kratos/v2/log"
	"github.com/project-kessel/inventory-consumer/internal/common"
	"github.com/project-kessel/inventory-consumer/internal/mocks"
	"github.com/project-kessel/kessel-sdk-go/kessel/auth"
	kesselgrpc "github.com/project-kessel/kessel-sdk-go/kessel/grpc"
	"github.com/project-kessel/kessel-sdk-go/kessel/inventory/v1beta2"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/mock"
)

func createTestConfig(enabled bool, enableOidcAuth bool, caCertFile string) CompletedConfig {
	options := &Options{
		Enabled:        enabled,
		InventoryURL:   "localhost:9000",
		Insecure:       true,
		EnableOidcAuth: enableOidcAuth,
		CACertFile:     caCertFile,
		ClientId:       "test-client",
		ClientSecret:   "test-secret",
		TokenEndpoint:  "http://localhost:8080/token",
	}

	return CompletedConfig{
		&completedConfig{
			Options: options,
		},
	}
}

func createTestLogger() *log.Helper {
	_, logger := common.InitLogger("info", common.LoggerOptions{})
	return log.NewHelper(log.With(logger, "service", "test"))
}

// createTestCACertData creates CA certificate data in memory for testing
func createTestCACertData(t *testing.T) []byte {
	// Create a self-signed CA certificate
	ca := &x509.Certificate{
		SerialNumber: big.NewInt(1),
		Subject: pkix.Name{
			Organization:  []string{"Test CA"},
			Country:       []string{"US"},
			Province:      []string{""},
			Locality:      []string{"Test City"},
			StreetAddress: []string{""},
			PostalCode:    []string{""},
		},
		NotBefore:             time.Now(),
		NotAfter:              time.Now().AddDate(1, 0, 0),
		IsCA:                  true,
		ExtKeyUsage:           []x509.ExtKeyUsage{x509.ExtKeyUsageClientAuth, x509.ExtKeyUsageServerAuth},
		KeyUsage:              x509.KeyUsageDigitalSignature | x509.KeyUsageCertSign,
		BasicConstraintsValid: true,
	}

	// Generate private key
	caPrivKey, err := rsa.GenerateKey(rand.Reader, 2048)
	if err != nil {
		t.Fatalf("Failed to generate CA private key: %v", err)
	}

	// Create the certificate
	caBytes, err := x509.CreateCertificate(rand.Reader, ca, ca, &caPrivKey.PublicKey, caPrivKey)
	if err != nil {
		t.Fatalf("Failed to create CA certificate: %v", err)
	}

	// Encode certificate to PEM format in memory
	pemData := pem.EncodeToMemory(&pem.Block{Type: "CERTIFICATE", Bytes: caBytes})
	return pemData
}

// newWithCACertData is a test helper that creates a client with in-memory CA cert data
func newWithCACertData(c CompletedConfig, logger *log.Helper, caCertData []byte) (*KesselClient, error) {
	logger.Info("Setting up Inventory API client")
	var client v1beta2.KesselInventoryServiceClient
	var err error

	if !c.Enabled {
		logger.Info("ClientProvider enabled: ", c.Enabled)
		return &KesselClient{Enabled: false}, nil
	}

	if c.EnableOidcAuth {
		oauthCredentials := auth.NewOAuth2ClientCredentials(c.ClientId, c.ClientSecret, c.TokenEndpoint)
		// Use the in-memory certificate data instead of reading from file
		channelCreds, err := configureTLSFromData(caCertData)
		if err != nil {
			return &KesselClient{}, fmt.Errorf("failed to setup transport credentials for TLS: %w", err)
		}
		client, _, err = v1beta2.NewClientBuilder(c.InventoryURL).
			Authenticated(kesselgrpc.OAuth2CallCredentials(&oauthCredentials), channelCreds).Build()

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

func TestNew(t *testing.T) {
	// Create CA cert data in memory for tests that need it
	caCertData := createTestCACertData(t)

	tests := []struct {
		name          string
		config        CompletedConfig
		expectEnabled bool
		expectAuth    bool
		shouldError   bool
		useInMemory   bool // Whether to use in-memory cert data
	}{
		{
			name:          "disabled client returns disabled KesselClient",
			config:        createTestConfig(false, false, ""),
			expectEnabled: false,
			expectAuth:    false,
			shouldError:   false,
			useInMemory:   false,
		},
		{
			name:          "enabled client without auth creates client successfully",
			config:        createTestConfig(true, false, ""),
			expectEnabled: true,
			expectAuth:    false,
			shouldError:   false,
			useInMemory:   false,
		},
		{
			name:          "enabled client with auth creates client successfully",
			config:        createTestConfig(true, true, ""),
			expectEnabled: true,
			expectAuth:    true,
			shouldError:   false,
			useInMemory:   true,
		},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			logger := createTestLogger()

			var client *KesselClient
			var err error

			if test.useInMemory {
				// Use the test helper with in-memory certificate data
				client, err = newWithCACertData(test.config, logger, caCertData)
			} else {
				// Use the regular New function
				client, err = New(test.config, logger)
			}

			if test.shouldError {
				assert.Error(t, err)
				return
			}

			assert.NoError(t, err)
			assert.NotNil(t, client)
			assert.Equal(t, test.expectEnabled, client.Enabled)
			assert.Equal(t, test.expectAuth, client.AuthEnabled)

			if !test.config.Enabled {
				// For disabled clients, KesselInventoryServiceClient should be nil
				assert.Nil(t, client.KesselInventoryServiceClient)
			} else {
				// For enabled clients, KesselInventoryServiceClient should be set
				assert.NotNil(t, client.KesselInventoryServiceClient)
			}
		})
	}
}

func TestConfigureTLSFromData(t *testing.T) {
	// Create test CA certificate data
	caCertData := createTestCACertData(t)

	// Test that configureTLSFromData works with valid certificate data
	creds, err := configureTLSFromData(caCertData)
	assert.NoError(t, err)
	assert.NotNil(t, creds)

	// Test that configureTLSFromData fails with invalid certificate data
	invalidData := []byte("invalid certificate data")
	creds, err = configureTLSFromData(invalidData)
	assert.Error(t, err)
	assert.Nil(t, creds)
}

func TestKesselClient_IsEnabled(t *testing.T) {
	tests := []struct {
		name     string
		enabled  bool
		expected bool
	}{
		{
			name:     "client is enabled",
			enabled:  true,
			expected: true,
		},
		{
			name:     "client is disabled",
			enabled:  false,
			expected: false,
		},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			client := &KesselClient{
				Enabled: test.enabled,
			}

			result := client.IsEnabled()
			assert.Equal(t, test.expected, result)
		})
	}
}

// TestClientProvider_CreateOrUpdateResource tests the ReportResource method using MockClient
func TestClientProvider_CreateOrUpdateResource(t *testing.T) {
	tests := []struct {
		name           string
		mockSetup      func(*mocks.MockClient)
		request        *v1beta2.ReportResourceRequest
		expectedResult *v1beta2.ReportResourceResponse
		expectedError  error
	}{
		{
			name: "successful create or update resource",
			mockSetup: func(m *mocks.MockClient) {
				m.On("ReportResource", mock.Anything).
					Return(&v1beta2.ReportResourceResponse{}, nil)
			},
			request: &v1beta2.ReportResourceRequest{
				Type:               "host",
				ReporterType:       "hbi",
				ReporterInstanceId: "test-instance",
			},
			expectedResult: &v1beta2.ReportResourceResponse{},
			expectedError:  nil,
		},
		{
			name: "create or update resource fails",
			mockSetup: func(m *mocks.MockClient) {
				m.On("ReportResource", mock.Anything).
					Return(&v1beta2.ReportResourceResponse{}, errors.New("grpc error"))
			},
			request: &v1beta2.ReportResourceRequest{
				Type:               "host",
				ReporterType:       "hbi",
				ReporterInstanceId: "test-instance",
			},
			expectedResult: &v1beta2.ReportResourceResponse{},
			expectedError:  errors.New("grpc error"),
		},
		{
			name: "create or update resource with specific request data",
			mockSetup: func(m *mocks.MockClient) {
				// Use mock.Anything for simpler matching
				m.On("ReportResource", mock.Anything).
					Return(&v1beta2.ReportResourceResponse{}, nil)
			},
			request: &v1beta2.ReportResourceRequest{
				Type:               "host",
				ReporterType:       "hbi",
				ReporterInstanceId: "specific-instance",
			},
			expectedResult: &v1beta2.ReportResourceResponse{},
			expectedError:  nil,
		},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			// Create mock client
			mockClient := &mocks.MockClient{}
			test.mockSetup(mockClient)

			// Use the mock as ClientProvider interface
			var client ClientProvider = mockClient

			// Call the method being tested
			result, err := client.ReportResource(test.request)

			// Assert expectations
			if test.expectedError != nil {
				assert.Error(t, err)
				assert.Equal(t, test.expectedError.Error(), err.Error())
			} else {
				assert.NoError(t, err)
			}

			assert.Equal(t, test.expectedResult, result)
			mockClient.AssertExpectations(t)
		})
	}
}

// TestClientProvider_DeleteResource tests the DeleteResource method using MockClient
func TestClientProvider_DeleteResource(t *testing.T) {
	tests := []struct {
		name           string
		mockSetup      func(*mocks.MockClient)
		request        *v1beta2.DeleteResourceRequest
		expectedResult *v1beta2.DeleteResourceResponse
		expectedError  error
	}{
		{
			name: "successful delete resource",
			mockSetup: func(m *mocks.MockClient) {
				m.On("DeleteResource", mock.Anything).
					Return(&v1beta2.DeleteResourceResponse{}, nil)
			},
			request: &v1beta2.DeleteResourceRequest{
				Reference: &v1beta2.ResourceReference{
					ResourceType: "host",
					ResourceId:   "test-host-id",
					Reporter: &v1beta2.ReporterReference{
						Type: "hbi",
					},
				},
			},
			expectedResult: &v1beta2.DeleteResourceResponse{},
			expectedError:  nil,
		},
		{
			name: "delete resource fails",
			mockSetup: func(m *mocks.MockClient) {
				m.On("DeleteResource", mock.Anything).
					Return(&v1beta2.DeleteResourceResponse{}, errors.New("delete failed"))
			},
			request: &v1beta2.DeleteResourceRequest{
				Reference: &v1beta2.ResourceReference{
					ResourceType: "host",
					ResourceId:   "test-host-id",
					Reporter: &v1beta2.ReporterReference{
						Type: "hbi",
					},
				},
			},
			expectedResult: &v1beta2.DeleteResourceResponse{},
			expectedError:  errors.New("delete failed"),
		},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			// Create mock client
			mockClient := &mocks.MockClient{}
			test.mockSetup(mockClient)

			// Use the mock as ClientProvider interface
			var client ClientProvider = mockClient

			// Call the method being tested
			result, err := client.DeleteResource(test.request)

			// Assert expectations
			if test.expectedError != nil {
				assert.Error(t, err)
				assert.Equal(t, test.expectedError.Error(), err.Error())
			} else {
				assert.NoError(t, err)
			}

			assert.Equal(t, test.expectedResult, result)
			mockClient.AssertExpectations(t)
		})
	}
}
