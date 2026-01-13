// Folder Upload Utility
// Detects folders in drag & drop, traverses them, creates ZIP in memory
// Returns a File object ready for the existing upload pipeline

import JSZip from "jszip"

const MAX_FOLDER_SIZE = 1024 * 1024 * 1024 // 1GB limit

// Check if a drop event contains folders
export function containsFolders(dataTransfer) {
  if (!dataTransfer.items) return false

  for (const item of dataTransfer.items) {
    if (item.kind === "file") {
      const entry = item.webkitGetAsEntry?.()
      if (entry?.isDirectory) return true
    }
  }
  return false
}

// Main entry point: process dropped items, return files (zipping folders)
export async function processDroppedItems(dataTransfer, onProgress) {
  const files = []
  const entries = []

  // Collect all entries
  for (const item of dataTransfer.items) {
    if (item.kind === "file") {
      const entry = item.webkitGetAsEntry?.()
      if (entry) {
        entries.push(entry)
      }
    }
  }

  for (const entry of entries) {
    if (entry.isDirectory) {
      // It's a folder - zip it
      const zippedFile = await zipFolder(entry, onProgress)
      files.push(zippedFile)
    } else {
      // Regular file - get it directly
      const file = await getFileFromEntry(entry)
      files.push(file)
    }
  }

  return files
}

// Convert a directory entry into a ZIP file
async function zipFolder(directoryEntry, onProgress) {
  const folderName = directoryEntry.name

  if (onProgress) onProgress({ phase: "scanning", folderName })

  // Recursively collect all files with their paths
  const fileEntries = await collectAllFiles(directoryEntry, "")

  // Calculate total size
  let totalSize = 0
  const filesToZip = []

  for (const { entry, path } of fileEntries) {
    const file = await getFileFromEntry(entry)
    totalSize += file.size
    filesToZip.push({ file, path })
  }

  // Check size limit
  if (totalSize > MAX_FOLDER_SIZE) {
    const sizeGB = (totalSize / (1024 * 1024 * 1024)).toFixed(2)
    throw new FolderTooLargeError(
      `Folder "${folderName}" is ${sizeGB}GB. Maximum folder size is 1GB. Please ZIP large folders manually.`
    )
  }

  if (onProgress) onProgress({
    phase: "zipping",
    folderName,
    fileCount: filesToZip.length,
    totalSize
  })

  // Create ZIP
  const zip = new JSZip()

  for (const { file, path } of filesToZip) {
    zip.file(path, file)
  }

  // Generate ZIP blob
  const zipBlob = await zip.generateAsync({
    type: "blob",
    compression: "DEFLATE",
    compressionOptions: { level: 6 }
  }, (metadata) => {
    if (onProgress) onProgress({
      phase: "compressing",
      folderName,
      percent: Math.round(metadata.percent)
    })
  })

  // Convert to File object with .zip extension
  const zipFileName = `${folderName}.zip`
  return new File([zipBlob], zipFileName, { type: "application/zip" })
}

// Recursively collect all file entries from a directory
async function collectAllFiles(directoryEntry, basePath) {
  const results = []
  const entries = await readDirectoryEntries(directoryEntry)

  for (const entry of entries) {
    const entryPath = basePath ? `${basePath}/${entry.name}` : entry.name

    if (entry.isDirectory) {
      const subFiles = await collectAllFiles(entry, entryPath)
      results.push(...subFiles)
    } else {
      results.push({ entry, path: entryPath })
    }
  }

  return results
}

// Promise wrapper for reading directory entries
function readDirectoryEntries(directoryEntry) {
  return new Promise((resolve, reject) => {
    const reader = directoryEntry.createReader()
    const allEntries = []

    // readEntries may not return all entries at once, must call repeatedly
    const readBatch = () => {
      reader.readEntries((entries) => {
        if (entries.length === 0) {
          resolve(allEntries)
        } else {
          allEntries.push(...entries)
          readBatch() // Continue reading
        }
      }, reject)
    }

    readBatch()
  })
}

// Promise wrapper for getting File from FileEntry
function getFileFromEntry(fileEntry) {
  return new Promise((resolve, reject) => {
    fileEntry.file(resolve, reject)
  })
}

// Custom error for size limit
export class FolderTooLargeError extends Error {
  constructor(message) {
    super(message)
    this.name = "FolderTooLargeError"
  }
}
