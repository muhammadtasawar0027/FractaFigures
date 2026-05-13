import SwiftUI

struct NotificationPermissionView: View {
    let onAccept: () -> Void
    let onSkip: () -> Void
    
    @State private var animateContent = false
    
    var body: some View {
        ZStack {
            Image("NotificationPermissionBackground")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()
            
            LinearGradient(
                colors: [
                    .black.opacity(0.03),
                    .black.opacity(0.03),
                    .black.opacity(0.08),
                    Color(red: 0.05, green: 0.05, blue: 0.13).opacity(0.22),
                    Color(red: 0.05, green: 0.05, blue: 0.13).opacity(0.82)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                VStack(spacing: 14) {
                    Button(action: onAccept) {
                        Text("YES, I WANT BONUSES!")
                            .font(.system(size: 24, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .minimumScaleFactor(0.72)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    Color(red: 1.0, green: 0.74, blue: 0.17),
                                                    Color(red: 1.0, green: 0.42, blue: 0.02)
                                                ],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        )
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color(red: 0.63, green: 0.19, blue: 0.02), lineWidth: 3)
                                    RoundedRectangle(cornerRadius: 9)
                                        .stroke(Color.white.opacity(0.42), lineWidth: 1)
                                        .padding(3)
                                }
                            )
                            .shadow(color: Color(red: 1.0, green: 0.55, blue: 0.0).opacity(0.35), radius: 10, x: 0, y: 4)
                            .shadow(color: .black.opacity(0.55), radius: 5, x: 0, y: 4)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: onSkip) {
                        Text("SKIP")
                            .font(.system(size: 21, weight: .heavy, design: .rounded))
                            .foregroundColor(.white.opacity(0.38))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 24)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.24),
                                                Color.white.opacity(0.16)
                                            ],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                            )
                            .shadow(color: .black.opacity(0.35), radius: 4, x: 0, y: 3)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 38)
                .padding(.top, 28)
                .padding(.bottom, 42)
                .opacity(animateContent ? 1.0 : 0)
                .offset(y: animateContent ? 0 : 20)
            }
        }
        .statusBarHidden(true)
        .onAppear {
            withAnimation(.easeOut(duration: 0.55)) {
                animateContent = true
            }
        }
    }
}
