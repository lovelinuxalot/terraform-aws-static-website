// +build unit

package test

import (
	"github.com/gruntwork-io/terratest/modules/terraform"
	test_structure "github.com/gruntwork-io/terratest/modules/test-structure"
	"github.com/stretchr/testify/assert"
	"path/filepath"
	"testing"
)

const cnameEnable = true

func TestStaticSiteValidity(t *testing.T) {
	t.Parallel()
	_fixturesDir := test_structure.CopyTerraformFolderToTemp(t, "../", "test/fixtures")
	examplesDir := filepath.Join(_fixturesDir, "static_website")
	terraformOptions := &terraform.Options{
		TerraformDir: examplesDir,
		Vars:         map[string]interface{}{},
	}
	t.Logf("Running in %s", examplesDir)
	output := terraform.InitAndPlan(t, terraformOptions)
	assert.Contains(t, output, "12 to add")
}

func TestStaticSiteValidityCnameEnabled(t *testing.T) {
	t.Parallel()
	_fixturesDir := test_structure.CopyTerraformFolderToTemp(t, "../", "test/fixtures")
	examplesDir := filepath.Join(_fixturesDir, "static_website")
	terraformOptions := &terraform.Options{
		TerraformDir: examplesDir,
		Vars: map[string]interface{}{
			"forward_www_cname": cnameEnable,
		},
	}
	t.Logf("Running in %s", examplesDir)
	output := terraform.InitAndPlan(t, terraformOptions)
	assert.Contains(t, output, "13 to add")
}
