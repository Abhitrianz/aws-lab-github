import * as cdk from 'aws-cdk-lib';
import { Template } from 'aws-cdk-lib/assertions';
import { ConnectivityTestStack } from '../lib/stacks/connectivity-test-stack';
import { DeploymentMarker } from '../lib/constructs';
import { EnvironmentConfig } from '../lib/config/environment';

const config: EnvironmentConfig = {
  appName: 'gh-cdk-connectivity',
  envName: 'dev',
  account: '111111111111',
  region: 'us-east-1',
  tags: { Application: 'gh-cdk-connectivity', Environment: 'dev' },
};

function synth(): Template {
  const app = new cdk.App();
  const stack = new ConnectivityTestStack(app, 'TestStack', {
    env: { account: config.account, region: config.region },
    config,
  });
  return Template.fromStack(stack);
}

describe('ConnectivityTestStack', () => {
  test('creates exactly one SSM deployment marker with the expected name', () => {
    const template = synth();
    template.resourceCountIs('AWS::SSM::Parameter', 1);
    template.hasResourceProperties('AWS::SSM::Parameter', {
      Name: '/gh-cdk-connectivity/dev/deployment-marker',
      Type: 'String',
    });
  });

  test('exposes account, region and parameter outputs', () => {
    const template = synth();
    template.hasOutput('DeploymentMarkerParameter', {});
    template.hasOutput('TargetAccount', {});
    template.hasOutput('TargetRegion', {});
  });
});

describe('DeploymentMarker', () => {
  test('rejects parameter names without a leading slash', () => {
    const stack = new cdk.Stack();
    expect(
      () => new DeploymentMarker(stack, 'Bad', { parameterName: 'no-slash', commitSha: 'x', runId: 'y' }),
    ).toThrow(/must start with/);
  });
});
