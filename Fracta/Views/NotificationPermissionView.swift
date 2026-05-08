import SwiftUI

struct NotificationPermissionView: View {
    let onAccept: () -> Void
    let onSkip: () -> Void
    
    @State private var animateContent = false
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.07, blue: 0.16),
                    Color(red: 0.13, green: 0.10, blue: 0.32),
                    Color(red: 0.32, green: 0.16, blue: 0.55)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                VStack(spacing: 28) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.08))
                            .frame(width: 160, height: 160)
                        Circle()
                            .fill(Color.white.opacity(0.16))
                            .frame(width: 110, height: 110)
                        Image(systemName: "bell.badge.fill")
                            .font(.system(size: 56, weight: .semibold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.yellow, .orange],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
                    .scaleEffect(animateContent ? 1.0 : 0.85)
                    .opacity(animateContent ? 1.0 : 0)
                    
                    VStack(spacing: 12) {
                        Text("Don't Miss Your Bonuses!")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                        
                        Text("Allow notifications to be the first to receive personal offers, gifts, and exclusive deals.")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.85))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    .opacity(animateContent ? 1.0 : 0)
                    .offset(y: animateContent ? 0 : 12)
                }
                
                Spacer()
                
                VStack(spacing: 14) {
                    Button(action: onAccept) {
                        Text("Yes, I Want Bonuses!")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(
                                LinearGradient(
                                    colors: [
                                        Color(red: 1.0, green: 0.55, blue: 0.20),
                                        Color(red: 1.0, green: 0.32, blue: 0.42)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                            .shadow(color: Color.orange.opacity(0.5), radius: 14, x: 0, y: 8)
                    }
                    
                    Button(action: onSkip) {
                        Text("Skip")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.85))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                    }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 40)
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
