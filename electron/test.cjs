'use strict'

const { test } = require('node:test')
const assert = require('node:assert/strict')
const path = require('node:path')
const { getDeviceInfo } = require('./index.cjs')

test('bundled helper returns the same stable JSON contract', { skip: process.platform !== 'darwin' }, async () => {
  const helper = path.resolve(__dirname, '../dist/universal/device-info')
  const info = await getDeviceInfo(helper)
  assert.ok(info.modelIdentifier.length > 0)
  assert.equal(info.isSimulator, false)
  assert.equal(info.deviceName, info.userAssignedName)
  assert.equal(info.displayModel, info.modelName ?? info.modelIdentifier)
  assert.equal(info.displayName, info.userAssignedName ?? info.deviceName ?? info.displayModel)
})

test('rejects relative executable paths', { skip: process.platform !== 'darwin' }, async () => {
  await assert.rejects(getDeviceInfo('./device-info'), /absolute path/)
})

test('propagates missing executable errors', { skip: process.platform !== 'darwin' }, async () => {
  await assert.rejects(getDeviceInfo('/nonexistent-apple-device-info/device-info'), { code: 'ENOENT' })
})
