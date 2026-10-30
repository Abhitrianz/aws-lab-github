import * as cdk from 'aws-cdk-lib';

export interface EnvironmentConfig {
  readonly appName: string;
  readonly envName: string;
  readonly account?: string;
  readonly region: string;
  readonly tags: Record<string, string>;
}

export const APP_NAME = 'gh-cdk-connectivity';

/**
 * Per-environment settings.
 * Add a new environment here and select it with `-c env=<name>`
 * (or the CDK_ENV variable in the GitHub workflow).
 */
export const ENVIRONMENTS: Record<string, { tags: Record<string, string> }> = {
  dev: { tags: { Environment: 'dev', CostCenter: 'sandbox' } },
  staging: { tags: { Environment: 'staging', CostCenter: 'platform' } },
  prod: { tags: { Environment: 'prod', CostCenter: 'platform' } },
};

/**
 * Resolves the environment from CDK context (`-c env=dev`).
 * Account and region come from the active AWS credentials, which the
 * CDK CLI exposes as CDK_DEFAULT_ACCOUNT / CDK_DEFAULT_REGION.
 */
export function loadEnvironment(app: cdk.App): EnvironmentConfig {
  const envName: string = app.node.tryGetContext('env') ?? 'dev';
  const known = ENVIRONMENTS[envName];

  if (!known) {
    throw new Error(
      `Unknown environment "${envName}". Known environments: ${Object.keys(ENVIRONMENTS).join(', ')}`,
    );
  }

  return {
    appName: APP_NAME,
    envName,
    account: process.env.CDK_DEFAULT_ACCOUNT,
    region: process.env.CDK_DEFAULT_REGION ?? process.env.AWS_REGION ?? 'us-east-1',
    tags: {
      Application: APP_NAME,
      ManagedBy: 'cdk',
      ...known.tags,
    },
  };
}
