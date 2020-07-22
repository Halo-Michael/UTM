//
// Copyright © 2020 osy. All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

import SwiftUI

// MARK: - Drives list

struct VMConfigDrivesView: View {
    @ObservedObject var config: UTMConfiguration
    @State private var createDriveVisible: Bool = false
    @State private var attemptDelete: IndexSet?
    @EnvironmentObject private var data: UTMData
    @Environment(\.importFiles) private var importFiles: ImportFilesAction
    
    var body: some View {
        Group {
            if config.countDrives == 0 {
                Text("No drives added.").font(.headline)
            } else {
                Form {
                    List {
                        ForEach(0..<config.countDrives, id: \.self) { index in
                            let fileName = config.driveImagePath(for: index) ?? ""
                            let imageType = config.driveImageType(for: index)
                            let interfaceType = config.driveInterfaceType(for: index) ?? ""
                            NavigationLink(
                                destination: VMConfigDriveDetailsView(config: config, index: index), label: {
                                    VStack(alignment: .leading) {
                                        Text(fileName)
                                            .lineLimit(1)
                                        HStack {
                                            Text(imageType.description).font(.caption)
                                            if imageType == .disk || imageType == .CD {
                                                Text("-")
                                                Text(interfaceType).font(.caption)
                                            }
                                        }
                                    }
                                })
                        }.onDelete { offsets in
                            attemptDelete = offsets
                        }
                        .onMove(perform: moveDrives)
                    }
                }
            }
        }
        .navigationBarItems(trailing:
            HStack {
                EditButton().padding(.trailing, 10)
                Button(action: importDrive, label: {
                    Label("Import Drive", systemImage: "square.and.arrow.down").labelStyle(IconOnlyLabelStyle())
                }).padding(.trailing, 10)
                Button(action: { createDriveVisible.toggle() }, label: {
                    Label("New Drive", systemImage: "plus").labelStyle(IconOnlyLabelStyle())
                })
            }
        )
        .sheet(isPresented: $createDriveVisible) {
            CreateDrive(onDismiss: newDrive)
        }
        .actionSheet(item: $attemptDelete) { offsets in
            ActionSheet(title: Text("Confirm Delete"), message: Text("Are you sure you want to permanently delete this disk image?"), buttons: [.cancel(), .destructive(Text("Delete")) {
                deleteDrives(offsets: offsets)
            }])
        }
    }
    
    private func importDrive() {
        importFiles(singleOfType: [.item]) { ret in
            data.busyWork {
                switch ret {
                case .success(let url):
                    try data.importDrive(url, forConfig: config)
                    break
                case .failure(let err):
                    throw err
                case .none:
                    break
                }
            }
        }
    }
    
    private func newDrive(driveImage: VMDriveImage) {
        data.busyWork {
            try data.createDrive(driveImage, forConfig: config)
        }
    }
    
    private func deleteDrives(offsets: IndexSet) {
        data.busyWork {
            for offset in offsets {
                try data.removeDrive(at: offset, forConfig: config)
            }
        }
    }
    
    private func moveDrives(source: IndexSet, destination: Int) {
        for offset in source {
            config.moveDrive(offset, to: destination)
        }
    }
}

// MARK: - Create Drive

private struct CreateDrive: View {
    let onDismiss: (VMDriveImage) -> Void
    @StateObject private var driveImage = VMDriveImage()
    @Environment(\.presentationMode) private var presentationMode: Binding<PresentationMode>
    
    init(onDismiss: @escaping (VMDriveImage) -> Void) {
        self.onDismiss = onDismiss
    }
    
    var body: some View {
        NavigationView {
            VMConfigDriveCreateView(driveImage: driveImage)
                .navigationBarItems(leading: Button(action: cancel, label: {
                    Text("Cancel")
                }), trailing: Button(action: done, label: {
                    Text("Done")
                }))
        }
    }
    
    private func cancel() {
        presentationMode.wrappedValue.dismiss()
    }
    
    private func done() {
        presentationMode.wrappedValue.dismiss()
        onDismiss(driveImage)
    }
}

// MARK: - Preview

struct VMConfigDrivesView_Previews: PreviewProvider {
    @ObservedObject static private var config = UTMConfiguration(name: "Test")
    
    static var previews: some View {
        Group {
            VMConfigDrivesView(config: config)
            CreateDrive { _ in
                
            }
        }.onAppear {
            if config.countDrives == 0 {
                config.newDrive("test.img", type: .disk, interface: "ide")
                config.newDrive("bios.bin", type: .BIOS, interface: UTMConfiguration.defaultDriveInterface())
            }
        }
    }
}
