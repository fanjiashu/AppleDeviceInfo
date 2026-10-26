'use strict'

const { execFile } = require('node:child_process')
const { isAbsolute } = require('node:path')
const { promisify } = require('node:util')
const execFileAsync = promisify(execFile)

/** Call only from the Electron main process, with an app-owned bundled executable. */
async function getDeviceInfo(helperPath) {
  if (process.platform !== 'darwin') {
    throw new Error('AppleDeviceInfo supports macOS only in Electron')
  }
  if (typeof helperPath !== 'string' || !isAbsolute(helperPath)) {
    throw new TypeError('helperPath must be an absolute path to the bundled device-info executable')
  }
  const { stdout } = await execFileAsync(helperPath, [], {
    encoding: 'utf8', timeout: 5000, maxBuffer: 64 * 1024, shell: false,
  })
  const info = JSON.parse(stdout)
  if (!info || typeof info !== 'object' || Array.isArray(info) ||
      typeof info.modelIdentifier !== 'string' || !info.modelIdentifier ||
      typeof info.isSimulator !== 'boolean' ||
      typeof info.displayModel !== 'string' || typeof info.displayName !== 'string' ||
      !['modelName', 'deviceName', 'userAssignedName'].every(
        key => info[key] === null || typeof info[key] === 'string'
      )) {
    throw new Error('device-info returned an invalid device snapshot')
  }
  return info
}

module.exports = { getDeviceInfo }
