#!/usr/bin/env node
import * as cdk from 'aws-cdk-lib';
import { loadEnvironment } from '../lib/config/environment';
import { ConnectivityTestStack } from '../lib/stacks/connectivity-test-stack';
import { applyTags } from '../lib/utils/tags';

const app = new cdk.App();
const config = loadEnvironment(app);

const stack = new ConnectivityTestStack(app, `${config.appName}-${config.envName}`, {
  env: { account: config.account, region: config.region },
  description: `GitHub Actions to AWS CDK connectivity test (${config.envName})`,
  config,
});

applyTags(stack, config.tags);
