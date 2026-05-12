import SwiftUI

struct ParticleEmitterView: View {
    enum Preset {
        case confetti
    }

    let preset: Preset
    let profile: AnimationProfile
    @State private var startTime: Date = .now

    private struct Particle: Identifiable {
        let id: Int
        let color: Color
        let startX: CGFloat
        let drift: CGFloat
        let spin: Double
        let size: CGFloat
        let duration: Double
        let delay: Double
    }

    private var particles: [Particle] {
        let count = profile.particleBudget
        guard count > 0 else { return [] }
        let palette: [Color] = [
            Color(red: 1.0, green: 0.78, blue: 0.42),
            Color(red: 0.96, green: 0.55, blue: 0.78),
            Color(red: 0.60, green: 0.78, blue: 0.96),
            Color(red: 0.70, green: 0.92, blue: 0.66),
            Color(red: 0.95, green: 0.93, blue: 0.55),
        ]
        var generator = SystemRandomNumberGenerator()
        return (0..<count).map { i in
            Particle(
                id: i,
                color: palette[i % palette.count],
                startX: CGFloat.random(in: 0...1, using: &generator),
                drift: CGFloat.random(in: -0.2...0.2, using: &generator),
                spin: Double.random(in: 0.5...3.5, using: &generator),
                size: CGFloat.random(in: 6...12, using: &generator),
                duration: Double.random(in: 1.8...3.0, using: &generator),
                delay: Double.random(in: 0...0.6, using: &generator)
            )
        }
    }

    var body: some View {
        if !profile.shouldShowParticles {
            EmptyView()
        } else {
            let snapshot = particles
            TimelineView(.animation) { context in
                Canvas { ctx, size in
                    let elapsed = context.date.timeIntervalSince(startTime)
                    for p in snapshot {
                        let local = elapsed - p.delay
                        guard local >= 0, local <= p.duration else { continue }
                        let progress = local / p.duration
                        let y = size.height * CGFloat(progress)
                        let x = size.width * (p.startX + p.drift * CGFloat(progress))
                        let rotation = Angle.degrees(p.spin * 360.0 * progress)
                        let rect = CGRect(
                            x: x - p.size / 2,
                            y: y - p.size / 2,
                            width: p.size,
                            height: p.size * 0.6
                        )
                        let transform = CGAffineTransform.identity
                            .translatedBy(x: rect.midX, y: rect.midY)
                            .rotated(by: rotation.radians)
                            .translatedBy(x: -rect.midX, y: -rect.midY)
                        let path = Path(rect).applying(transform)
                        ctx.fill(path, with: .color(p.color.opacity(1.0 - progress * 0.4)))
                    }
                }
            }
            .allowsHitTesting(false)
        }
    }
}

#if DEBUG
#Preview("Confetti normal") {
    ParticleEmitterView(
        preset: .confetti,
        profile: AnimationProfile(reduceMotion: false, lowPower: false)
    )
    .frame(width: 320, height: 480)
    .background(Color.black)
}

#Preview("Confetti low power") {
    ParticleEmitterView(
        preset: .confetti,
        profile: AnimationProfile(reduceMotion: false, lowPower: true)
    )
    .frame(width: 320, height: 480)
    .background(Color.black)
}
#endif
