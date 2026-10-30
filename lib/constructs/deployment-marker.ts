import { Construct } from 'constructs';
import * as ssm from 'aws-cdk-lib/aws-ssm';

export interface DeploymentMarkerProps {
  /** Full SSM parameter path, for example /app/dev/deployment-marker */
  readonly parameterName: string;
  /** Git commit SHA that produced this deployment */
  readonly commitSha: string;
  /** GitHub Actions run ID (or "local") */
  readonly runId: string;
  /** Who/what triggered the deployment (GitHub actor or "local") */
  readonly triggeredBy?: string;
}

/**
 * Reusable construct: writes a small JSON record to SSM Parameter Store
 * describing the deployment. It is free (standard tier) and gives a
 * verifiable proof that CI deployed into the intended account.
 */
export class DeploymentMarker extends Construct {
  public readonly parameter: ssm.StringParameter;

  constructor(scope: Construct, id: string, props: DeploymentMarkerProps) {
    super(scope, id);

    if (!props.parameterName.startsWith('/')) {
      throw new Error(`parameterName must start with "/": ${props.parameterName}`);
    }

    this.parameter = new ssm.StringParameter(this, 'Parameter', {
      parameterName: props.parameterName,
      description: 'Deployment marker written by AWS CDK',
      tier: ssm.ParameterTier.STANDARD,
      stringValue: JSON.stringify({
        commitSha: props.commitSha,
        runId: props.runId,
        triggeredBy: props.triggeredBy ?? 'unknown',
      }),
    });
  }
}
