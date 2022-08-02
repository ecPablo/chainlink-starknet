package integration_tests

import (
	"encoding/json"
	"fmt"
	"io/ioutil"

	gauntlet "github.com/smartcontractkit/chainlink-testing-framework/gauntlet"
)

var (
	sg *StarknetGauntlet
)

type StarknetGauntlet struct {
	g       *gauntlet.Gauntlet
	options *gauntlet.ExecCommandOptions
}

// Default response output for starknet gauntlet commands
type GauntletResponse struct {
	Responses []struct {
		Tx struct {
			Hash    string `json:"hash"`
			Address string `json:"address"`
			Status  string `json:"status"`
			Tx      struct {
				Address         string   `json:"address"`
				Code            string   `json:"code"`
				Result          []string `json:"result"`
				TransactionHash string   `json:"transaction_hash"`
			} `json:"tx"`
		} `json:"tx"`
		Contract string `json:"contract"`
	} `json:"responses"`
}

// Default config for OCR2 for starknet
type OCR2Config struct {
	F                     int             `json:"f"`
	Signers               []string        `json:"signers"`
	Transmitters          []string        `json:"transmitters"`
	OnchainConfig         string          `json:"onchainConfig"`
	OffchainConfig        *OffchainConfig `json:"offchainConfig"`
	OffchainConfigVersion int             `json:"offchainConfigVersion"`
	Secret                string          `json:"secret"`
}

type OffchainConfig struct {
	DeltaProgressNanoseconds                           int64                  `json:"deltaProgressNanoseconds"`
	DeltaResendNanoseconds                             int64                  `json:"deltaResendNanoseconds"`
	DeltaRoundNanoseconds                              int64                  `json:"deltaRoundNanoseconds"`
	DeltaGraceNanoseconds                              int                    `json:"deltaGraceNanoseconds"`
	DeltaStageNanoseconds                              int64                  `json:"deltaStageNanoseconds"`
	RMax                                               int                    `json:"rMax"`
	S                                                  []int                  `json:"s"`
	OffchainPublicKeys                                 []string               `json:"offchainPublicKeys"`
	PeerIds                                            []string               `json:"peerIds"`
	ReportingPluginConfig                              *ReportingPluginConfig `json:"reportingPluginConfig"`
	MaxDurationQueryNanoseconds                        int                    `json:"maxDurationQueryNanoseconds"`
	MaxDurationObservationNanoseconds                  int                    `json:"maxDurationObservationNanoseconds"`
	MaxDurationReportNanoseconds                       int                    `json:"maxDurationReportNanoseconds"`
	MaxDurationShouldAcceptFinalizedReportNanoseconds  int                    `json:"maxDurationShouldAcceptFinalizedReportNanoseconds"`
	MaxDurationShouldTransmitAcceptedReportNanoseconds int                    `json:"maxDurationShouldTransmitAcceptedReportNanoseconds"`
}

type ReportingPluginConfig struct {
	AlphaReportInfinite bool `json:"alphaReportInfinite"`
	AlphaReportPpb      int  `json:"alphaReportPpb"`
	AlphaAcceptInfinite bool `json:"alphaAcceptInfinite"`
	AlphaAcceptPpb      int  `json:"alphaAcceptPpb"`
	DeltaCNanoseconds   int  `json:"deltaCNanoseconds"`
}

// Creates a default gauntlet config
func NewStarknetGauntlet() (*gauntlet.Gauntlet, error) {
	g, err := gauntlet.NewGauntlet()
	if err != nil {
		return nil, err
	}
	sg = &StarknetGauntlet{
		g: g,
		options: &gauntlet.ExecCommandOptions{
			ErrHandling:       []string{},
			CheckErrorsInRead: true,
		},
	}
	return g, nil
}

// Parse gauntlet json response that is generated after yarn gauntlet command execution
func FetchGauntletJsonOutput() (*GauntletResponse, error) {
	var payload = &GauntletResponse{}
	gauntletOutput, err := ioutil.ReadFile("../../report.json")
	if err != nil {
		return payload, err
	}
	err = json.Unmarshal(gauntletOutput, &payload)
	if err != nil {
		return payload, err
	}

	return payload, nil
}

// Loads and returns the default starknet gauntlet config
func LoadOCR2Config(nKeys []NodeKeysBundle) (*OCR2Config, error) {
	var offChainKeys []string
	var onChainKeys []string
	var peerIds []string
	var txKeys []string
	for _, key := range nKeys {
		offChainKeys = append(offChainKeys, key.OCR2Key.Data.Attributes.OffChainPublicKey)
		peerIds = append(peerIds, key.PeerID)
		txKeys = append(txKeys, key.TXKey.Data.ID)
		onChainKeys = append(onChainKeys, key.OCR2Key.Data.Attributes.OnChainPublicKey)
	}

	var payload = &OCR2Config{
		F:             1,
		Signers:       onChainKeys,
		Transmitters:  txKeys,
		OnchainConfig: "",
		OffchainConfig: &OffchainConfig{
			DeltaProgressNanoseconds: 8000000000,
			DeltaResendNanoseconds:   30000000000,
			DeltaRoundNanoseconds:    3000000000,
			DeltaGraceNanoseconds:    500000000,
			DeltaStageNanoseconds:    20000000000,
			RMax:                     5,
			S:                        []int{1, 2},
			OffchainPublicKeys:       offChainKeys,
			PeerIds:                  peerIds,
			ReportingPluginConfig: &ReportingPluginConfig{
				AlphaReportInfinite: false,
				AlphaReportPpb:      0,
				AlphaAcceptInfinite: false,
				AlphaAcceptPpb:      0,
				DeltaCNanoseconds:   0,
			},
			MaxDurationQueryNanoseconds:                        0,
			MaxDurationObservationNanoseconds:                  1000000000,
			MaxDurationReportNanoseconds:                       200000000,
			MaxDurationShouldAcceptFinalizedReportNanoseconds:  200000000,
			MaxDurationShouldTransmitAcceptedReportNanoseconds: 200000000,
		},
		OffchainConfigVersion: 2,
		Secret:                "awe accuse polygon tonic depart acuity onyx inform bound gilbert expire",
	}

	return payload, nil
}

func (sg *StarknetGauntlet) DeployOCR2ControllerContract(minSubmissionValue int64, maxSubmissionValue int64, decimals int, name string) error {
	_, err := sg.g.ExecCommand([]string{"ocr2:deploy", fmt.Sprintf("--minSubmissionValue=%d", minSubmissionValue), fmt.Sprintf("--maxSubmissionValue=%d", maxSubmissionValue), fmt.Sprintf("--decimals=%d", decimals), fmt.Sprintf("--name=%s", name)}, *sg.options)
	if err != nil {
		return err
	}

	return nil
}
