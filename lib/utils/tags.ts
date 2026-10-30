import * as cdk from 'aws-cdk-lib';
import { Construct } from 'constructs';

/** Applies a set of tags to every taggable resource under the given scope. */
export function applyTags(scope: Construct, tags: Record<string, string>): void {
  for (const [key, value] of Object.entries(tags)) {
    cdk.Tags.of(scope).add(key, value);
  }
}
