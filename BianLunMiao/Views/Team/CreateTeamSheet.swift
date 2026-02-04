import SwiftUI

struct CreateTeamSheet: View {
    @Environment(\.dismiss) var dismiss
    
    @State private var name: String
    @State private var intro: String
    @State private var generatedId: String
    
    var isEditing: Bool = false
    var onSave: (String, String) -> Void
    
    init(team: Team? = nil, onSave: @escaping (String, String) -> Void) {
        _name = State(initialValue: team?.name ?? "")
        _intro = State(initialValue: team?.intro ?? "")
        _generatedId = State(initialValue: team?.publicId ?? "8888")
        self.isEditing = team != nil
        self.onSave = onSave
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 12) {
                            Circle()
                                .fill(Color.gray.opacity(0.1))
                                .frame(width: 80, height: 80)
                                .overlay(
                                    Image(systemName: "camera.fill")
                                        .foregroundColor(.blue)
                                )
                            Text("上传队徽")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }
                
                Section("基本信息") {
                    TextField("队伍名称", text: $name)
                    
                    HStack {
                        Text("队伍 ID")
                        Spacer()
                        Text(generatedId)
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                }
                
                Section("简介") {
                    TextField("一句话介绍你的队伍", text: $intro, axis: .vertical)
                        .lineLimit(3...5)
                }
            }
            .navigationTitle(isEditing ? "编辑队伍" : "创建队伍")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        onSave(name, intro)
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
            .onAppear {
                if !isEditing {
                    generatedId = String(Int.random(in: 1000...9999))
                }
            }
        }
    }
}

#Preview {
    CreateTeamSheet { _, _ in }
}
