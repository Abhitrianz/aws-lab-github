import * as cdk from 'aws-cdk-lib';
import { Construct } from 'constructs';
import { EnvironmentConfig } from '../config/environment';
import { DeploymentMarker } from '../constructs';

export interface ConnectivityTestStackProps extends cdk.StackProps {
  readonly config: EnvironmentConfig;
}

/**
 * Minimal, zero-cost stack used to prove the GitHub -> AWS pipeline works.
 * Replace or extend with real resources once the connection is confirmed.
 */
export class ConnectivityTestStack extends cdk.Stack {
  public readonly markerParameterName: string;

  constructor(scope: Construct, id: string, props: ConnectivityTestStackProps) {
    super(scope, id, props);

    const { config } = props;
    this.markerParameterName = `/${config.appName}/${config.envName}/deployment-marker`;

    const marker = new DeploymentMarker(this, 'DeploymentMarker', {
      parameterName: this.markerParameterName,
      commitSha: process.env.GITHUB_SHA ?? 'local',
      runId: process.env.GITHUB_RUN_ID ?? 'local',
      triggeredBy: process.env.GITHUB_ACTOR ?? 'local',
    });

    new cdk.CfnOutput(this, 'DeploymentMarkerParameter', {
      value: marker.parameter.parameterName,
      description: 'SSM parameter written by this deployment',
    });

    new cdk.CfnOutput(this, 'TargetAccount', {
      value: this.account,
      description: 'AWS account this stack was deployed into',
    });

    new cdk.CfnOutput(this, 'TargetRegion', {
      value: this.region,
      description: 'AWS region this stack was deployed into',
    });
  }
}
