import SwiftUI

struct CreateTournamentView: View {
    @Environment(\.dismiss) var dismiss
    
    @State private var name: String = ""
    @State private var intro: String = ""
    
    var onSave: (String, String) -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    TextField("赛事名称", text: $name)
                    TextField("赛事简介", text: $intro, axis: .vertical)
                        .lineLimit(3...5)
                }
            }
            .navigationTitle("发起赛事")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("创建") {
                        onSave(name, intro)
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}
