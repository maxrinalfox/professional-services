#!/bin/bash

# Script to execute all Creative Studio Cloud Build triggers
# Usage: ./run_cloud_build_triggers.sh <project-id> [region] [environment] [--execute]

# Default: dry-run mode (print commands, don't execute)
# Add --execute flag to actually run the triggers

PROJECT_ID=""
REGION="us-central1"
ENVIRONMENT="development"
DRY_RUN=true

# Parse arguments flexibly - support --execute flag anywhere
for arg in "$@"; do
  case "$arg" in
    --execute)
      DRY_RUN=false
      ;;
    --region=*)
      REGION="${arg#--region=}"
      ;;
    --environment=*)
      ENVIRONMENT="${arg#--environment=}"
      ;;
    --help|-h)
      echo "Usage: $0 [project-id] [--region=REGION] [--environment=ENV] [--execute]"
      echo ""
      echo "Examples:"
      echo "  Dry-run (auto-detect project):"
      echo "    $0"
      echo ""
      echo "  Execute with current project:"
      echo "    $0 --execute"
      echo ""
      echo "  Custom project:"
      echo "    $0 my-project --execute"
      echo ""
      echo "  Custom environment:"
      echo "    $0 --environment=production --execute"
      exit 0
      ;;
    -*)
      echo "Unknown option: $arg"
      exit 1
      ;;
    *)
      # First non-flag argument is project ID
      if [ -z "$PROJECT_ID" ]; then
        PROJECT_ID="$arg"
      fi
      ;;
  esac
done

# Auto-detect project ID from gcloud config if not provided
if [ -z "$PROJECT_ID" ]; then
  PROJECT_ID=$(gcloud config get project 2>/dev/null)
  if [ $? -ne 0 ] || [ -z "$PROJECT_ID" ]; then
    echo "Error: Could not determine GCP project ID"
    echo "Please set your default project: gcloud config set project PROJECT_ID"
    exit 1
  fi
fi

# Get current git branch if not in a git repo, use 'main' as fallback
CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "main")


echo "=========================================="
echo "Cloud Build Triggers Executor"
echo "=========================================="
echo "Project ID: $PROJECT_ID"
echo "Region: $REGION"
echo "Environment: $ENVIRONMENT"
echo "Branch: $CURRENT_BRANCH"
if [ "$DRY_RUN" = true ]; then
  echo "Mode: DRY-RUN (printing commands only)"
else
  echo "Mode: EXECUTE (actually running triggers)"
fi
echo ""

# Construct trigger names based on environment
BACKEND_TRIGGER="cstudio-${ENVIRONMENT}-backend-trigger"
BOOTSTRAP_TRIGGER="cstudio-${ENVIRONMENT}-bootstrap-trigger"
FRONTEND_TRIGGER="cstudio-${ENVIRONMENT}-frontend-trigger"

# Array of triggers to execute
TRIGGERS=("$BOOTSTRAP_TRIGGER" "$BACKEND_TRIGGER" "$FRONTEND_TRIGGER")

echo "Triggers to execute (in order):"
for trigger in "${TRIGGERS[@]}"; do
  echo "  1. $trigger"
done
echo ""

# Execute each trigger
EXECUTED_COUNT=0
SKIPPED_COUNT=0

for trigger in "${TRIGGERS[@]}"; do
  echo "=========================================="
  echo "Trigger: $trigger"
  echo "=========================================="

  # Build the command
  CMD="gcloud builds triggers run \"$trigger\" --region=\"$REGION\" --project=\"$PROJECT_ID\" --branch=\"$CURRENT_BRANCH\""

  if [ "$DRY_RUN" = true ]; then
    # Dry-run mode: print the command
    echo "Command:"
    echo "  $CMD"
    echo ""
    echo "✓ Copy and paste the command above to execute"
    ((EXECUTED_COUNT++))
  else
    # Execute mode: actually run the command
    echo "Executing..."
    echo "  $CMD"
    echo ""

    if gcloud builds triggers run "$trigger" \
      --region="$REGION" \
      --project="$PROJECT_ID" \
      --branch="$CURRENT_BRANCH"; then

      echo "✅ $trigger executed successfully"
      ((EXECUTED_COUNT++))
    else
      echo "⚠️  Failed to execute trigger '$trigger'"
      ((SKIPPED_COUNT++))
    fi
  fi

  echo ""
done

echo "=========================================="
echo "Summary"
echo "=========================================="
if [ "$DRY_RUN" = true ]; then
  echo "Commands generated: $EXECUTED_COUNT"
  echo ""
  echo "Next steps:"
  echo "  1. Review the commands above"
  echo "  2. To execute them, run:"
  echo "     $0 $PROJECT_ID $REGION $ENVIRONMENT --execute"
  echo ""
  echo "Or copy and paste individual commands directly."
else
  echo "Executed: $EXECUTED_COUNT triggers"
  echo "Failed: $SKIPPED_COUNT triggers"
  echo ""
  if [ "$EXECUTED_COUNT" -gt 0 ]; then
    echo "Build IDs to monitor:"
    echo "  gcloud builds list --project=$PROJECT_ID --limit=10"
    echo ""
    echo "View full logs:"
    echo "  gcloud builds log <BUILD_ID> --project=$PROJECT_ID"
  fi
fi
echo ""
echo "To list all triggers:"
echo "  gcloud builds triggers list --region=$REGION --project=$PROJECT_ID"
