export interface RunRequest {
  userSegment: string;
  cwd: string;
  command: string;
  timeoutMs?: number;
  maxBufferBytes?: number;
}

export interface RunResponse {
  stdout: string;
  stderr: string;
  exitCode: number;
}
