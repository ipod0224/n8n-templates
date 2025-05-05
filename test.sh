#!/bin/bash
echo "Testing workflow validation..."
node validate.js workflows/*.json
if [ $? -eq 0 ]; then
  echo "✅ All tests passed!"
  exit 0
else
  echo "❌ Test failed!"
  exit 1
fi
