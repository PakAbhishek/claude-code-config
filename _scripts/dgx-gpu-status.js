#!/usr/bin/env node
/**
 * DGX Spark GPU Status Hook for Claude Code
 * Runs on SessionStart to display GB10 Superchip status
 * Hardware: NVIDIA DGX Spark (Grace Blackwell GB10)
 */

const { execSync } = require('child_process');

function getDGXSparkStatus() {
  try {
    // Query GPU and unified memory stats
    const output = execSync(
      'nvidia-smi --query-gpu=name,memory.used,memory.total,utilization.gpu,temperature.gpu,power.draw --format=csv,noheader,nounits',
      { encoding: 'utf8', stdio: ['pipe', 'pipe', 'pipe'] }
    );

    const [name, memUsed, memTotal, util, temp, power] = output
      .trim()
      .split(',')
      .map(s => s.trim());

    // Calculate memory usage
    const memUsedGB = (parseFloat(memUsed) / 1024).toFixed(1);
    const memTotalGB = (parseFloat(memTotal) / 1024).toFixed(1);
    const memPercent = ((parseFloat(memUsed) / parseFloat(memTotal)) * 100).toFixed(1);

    // Parse utilization, temperature, and power
    const utilPercent = parseInt(util);
    const tempCelsius = parseInt(temp);
    const powerWatts = parseFloat(power);

    // Display status
    console.log('');
    console.log('═══════════════════════════════════════════');
    console.log('  DGX Spark - GB10 Superchip Status');
    console.log('═══════════════════════════════════════════');
    console.log(`System: ${name}`);
    console.log(`Unified Memory: ${memUsedGB} / ${memTotalGB} GB (${memPercent}%)`);
    console.log(`GPU Utilization: ${utilPercent}%`);
    console.log(`Temperature: ${tempCelsius}°C`);
    console.log(`Power Draw: ${powerWatts}W / 140W TDP`);

    // Warnings
    const warnings = [];
    if (tempCelsius > 75) {
      warnings.push('⚠️  High temperature detected');
    }
    if (powerWatts > 130) {
      warnings.push('⚠️  Near TDP limit');
    }
    if (parseFloat(memPercent) > 90) {
      warnings.push('⚠️  Unified memory >90% used');
    }

    if (warnings.length > 0) {
      console.log('');
      warnings.forEach(w => console.log(w));
    }

    console.log('═══════════════════════════════════════════');
    console.log('');
    return true;
  } catch (err) {
    // Silent fail - GPU monitoring is optional
    // Don't spam output if nvidia-smi is not available
    if (process.env.DEBUG_GPU_HOOK) {
      console.log('DGX Spark status unavailable:', err.message);
    }
    return false;
  }
}

// Main execution
try {
  getDGXSparkStatus();
  process.exit(0);
} catch (err) {
  // Never block Claude Code startup
  if (process.env.DEBUG_GPU_HOOK) {
    console.error('GPU status hook error:', err.message);
  }
  process.exit(0);
}
