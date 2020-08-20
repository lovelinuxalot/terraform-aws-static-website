// +build integration

package test

import (
	"fmt"
	http_helper "github.com/gruntwork-io/terratest/modules/http-helper"
	"github.com/gruntwork-io/terratest/modules/logger"
	"github.com/gruntwork-io/terratest/modules/retry"
	"github.com/gruntwork-io/terratest/modules/terraform"
	test_structure "github.com/gruntwork-io/terratest/modules/test-structure"
	"github.com/stretchr/testify/assert"
	"path/filepath"
	"testing"
	"time"
)

const websiteName = "testsite"
const websiteOutput = "website_endpoint"

var certificate_arn = "arn:aws:certificate_arn"
var forward_www_cname = true
var region = "eu-central-1"
var cidr_whitelist = []string{
	"0.0.0.0/0",
}
var customTags = map[string]string{
	"Name": "Terratest",
	"Env":  "Test",
}

func TestStaticSiteDeployment(t *testing.T) {
	t.Parallel()

	// Uncomment these when doing local testing if you need to skip any stages.
	// For faster feedback in testing and to avoid creating and destroying resources always

	//os.Setenv("SKIP_bootstrap", "true")
	//os.Setenv("SKIP_apply", "true")
	//os.Setenv("SKIP_perpetual_diff", "true")
	//os.Setenv("SKIP_website_tests", "true")
	//os.Setenv("SKIP_destroy", "true")

	_examplesDir := test_structure.CopyTerraformFolderToTemp(t, "../", "examples")
	exampleDir := filepath.Join(_examplesDir, "static_website")

	defer test_structure.RunTestStage(t, "teardown", func() {
		terraformOptions := test_structure.LoadTerraformOptions(t, exampleDir)
		terraform.Destroy(t, terraformOptions)
	})
	test_structure.RunTestStage(t, "apply", func() {
		terratestOptions := &terraform.Options{
			TerraformDir: exampleDir,
			Vars: map[string]interface{}{
				"website_name":      websiteName,
				"custom_tags":       customTags,
				"region":            region,
				"forward_www_cname": forward_www_cname,
				"certificate_arn":   certificate_arn,
				"cidr_whitelist":    cidr_whitelist,
			},
		}
		test_structure.SaveTerraformOptions(t, exampleDir, terratestOptions)
		terraform.InitAndApply(t, terratestOptions)
	})

	test_structure.RunTestStage(t, "perpetual_diff", func() {
		terraformOptions := test_structure.LoadTerraformOptions(t, exampleDir)
		planResult := terraform.Plan(t, terraformOptions)
		assert.Contains(t, planResult, "No changes")
	})

	test_structure.RunTestStage(t, "website_tests", func() {
		terraformOptions := test_structure.LoadTerraformOptions(t, exampleDir)
		websiteEndpoint := terraform.OutputRequired(t, terraformOptions, websiteOutput)

		testURL(t, websiteEndpoint, "", 200, "Hello, index!")
		testURL(t, websiteEndpoint, "anythingelse", 404, "Hello, error!")
	})
}

func testURL(t *testing.T, endpoint string, path string, expectedStatus int, expectedBody string) {
	url := fmt.Sprintf("%s://%s/%s", "http", endpoint, path)
	actionDescription := fmt.Sprintf("Calling %s", url)
	output := retry.DoWithRetry(t, actionDescription, 10, 10*time.Second, func() (string, error) {
		statusCode, body := http_helper.HttpGet(t, url, nil)
		if statusCode == expectedStatus {
			logger.Logf(t, "Got the expected staus code %d from URL %s", expectedStatus, url)
			return body, nil
		}
		return "", fmt.Errorf("Got status %d instead of the expected %d from %s", statusCode, expectedStatus, url)
	})
	assert.Containsf(t, output, expectedBody, "body should contain expected text")
}
