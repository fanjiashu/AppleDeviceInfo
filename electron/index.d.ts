export interface DeviceSnapshot {
  modelIdentifier: string
  modelName: string | null
  deviceName: string | null
  userAssignedName: string | null
  isSimulator: boolean
  displayModel: string
  displayName: string
}

/** Run in Electron main; helperPath must point to your bundled macOS executable. */
export function getDeviceInfo(helperPath: string): Promise<DeviceSnapshot>
