import SwiftUI
import Combine

struct BalanceDisplayView: View {
    let balance: UnifiedBalance
    @State private var displayBalance: Double = 0
    @State private var previousBalance: Double = 0
    @State private var changeAmount: Double = 1234.56
    @State private var changePercentage: Double = 2.4
    @State private var numberScale: CGFloat = 1.0
    @State private var numberOpacity: Double = 1.0
    @State private var isFirstAppear = true
    @State private var chartData: [ChartDataPoint] = []
    @State private var showChart = false
    @Environment(\.colorScheme) var colorScheme
    
    private let balanceSubject = PassthroughSubject<Double, Never>()
    
    var body: some View {
        VStack(spacing: 0) {
            // Main Balance Display
            VStack(spacing: WalletDesign.Spacing.tight) {
                // Balance Label
                Text("Total Balance")
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundColor(.secondary)
                    .opacity(isFirstAppear ? 0 : 1)
                    .animation(.easeIn(duration: 0.3).delay(0.2), value: isFirstAppear)
                
                // Animated Balance Number
                ZStack {
                    // Current Balance
                    BalanceNumber(value: displayBalance)
                        .scaleEffect(numberScale)
                        .opacity(numberOpacity)
                    
                    // Transition Effect
                    if previousBalance != displayBalance {
                        BalanceNumber(value: previousBalance)
                            .scaleEffect(1.1)
                            .opacity(0)
                            .animation(.easeOut(duration: 0.3), value: displayBalance)
                    }
                }
                .frame(height: 60)
                
                // Change Indicators
                HStack(spacing: WalletDesign.Spacing.regular) {
                    // 24h Change
                    ChangeIndicator(
                        amount: changeAmount,
                        percentage: changePercentage,
                        period: "24h"
                    )
                    .opacity(isFirstAppear ? 0 : 1)
                    .animation(.easeIn(duration: 0.3).delay(0.4), value: isFirstAppear)
                    
                    Spacer()
                    
                    // Portfolio Indicator
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        
                        Text("Healthy")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                    .opacity(isFirstAppear ? 0 : 1)
                    .animation(.easeIn(duration: 0.3).delay(0.5), value: isFirstAppear)
                }
                .padding(.horizontal, WalletDesign.Spacing.loose)
            }
            .padding(.vertical, WalletDesign.Spacing.section)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(WalletDesign.Animation.spring) {
                    showChart.toggle()
                }
                HapticManager.selection()
            }
            
            // Expandable Chart
            if showChart {
                MiniChartView(data: chartData)
                    .frame(height: 120)
                    .padding(.horizontal, WalletDesign.Spacing.regular)
                    .padding(.bottom, WalletDesign.Spacing.regular)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.95).combined(with: .opacity),
                        removal: .scale(scale: 0.95).combined(with: .opacity)
                    ))
            }
        }
        .onAppear {
            animateBalance()
            generateMockChartData()
        }
        .onReceive(balanceSubject) { newValue in
            animateBalanceChange(to: newValue)
        }
    }
    
    private func animateBalance() {
        let targetBalance = Double(balance.unifiedBalance.totalUsdValue) ?? 0
        
        if isFirstAppear {
            // Initial animation
            withAnimation(.easeOut(duration: 0.8)) {
                displayBalance = targetBalance
            }
            
            // Number bounce effect
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.2)) {
                numberScale = 1.05
            }
            
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8).delay(0.5)) {
                numberScale = 1.0
            }
            
            isFirstAppear = false
        } else {
            // Update animation
            animateBalanceChange(to: targetBalance)
        }
    }
    
    private func animateBalanceChange(to newValue: Double) {
        previousBalance = displayBalance
        
        // Fade out
        withAnimation(.easeOut(duration: 0.15)) {
            numberOpacity = 0.3
            numberScale = 0.98
        }
        
        // Update value and fade in
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            displayBalance = newValue
            
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                numberOpacity = 1.0
                numberScale = 1.0
            }
        }
    }
    
    private func generateMockChartData() {
        var data: [ChartDataPoint] = []
        let currentBalance = Double(balance.unifiedBalance.totalUsdValue) ?? 100000
        
        for i in 0..<24 {
            let variation = Double.random(in: -0.02...0.03)
            let value = currentBalance * (1 + variation * Double(24 - i) / 24)
            data.append(ChartDataPoint(time: Date().addingTimeInterval(-Double(i) * 3600), value: value))
        }
        
        chartData = data.reversed()
    }
}

// MARK: - Balance Number Component
struct BalanceNumber: View {
    let value: Double
    
    var body: some View {
        Text(value.formatAsBalance())
            .font(WalletDesign.Typography.balanceDisplay)
            .foregroundColor(.primary)
            .minimumScaleFactor(0.5)
            .lineLimit(1)
    }
}

// MARK: - Change Indicator
struct ChangeIndicator: View {
    let amount: Double
    let percentage: Double
    let period: String
    
    private var isPositive: Bool { amount >= 0 }
    
    var body: some View {
        HStack(spacing: 4) {
            // Arrow Icon
            Image(systemName: isPositive ? "arrow.up.right" : "arrow.down.right")
                .font(.system(size: 12, weight: .bold))
                .rotationEffect(.degrees(isPositive ? 0 : 0))
            
            // Amount
            Text("\(isPositive ? "+" : "")$\(abs(amount), specifier: "%.2f")")
                .font(.system(size: 15, weight: .medium, design: .rounded))
            
            // Percentage
            Text("(\(isPositive ? "+" : "")\(percentage, specifier: "%.1f")%)")
                .font(.system(size: 15, weight: .regular, design: .rounded))
            
            // Period
            Text(period)
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundColor(.secondary)
        }
        .foregroundColor(isPositive ? WalletDesign.Colors.positiveChange : WalletDesign.Colors.negativeChange)
    }
}

// MARK: - Mini Chart View
struct MiniChartView: View {
    let data: [ChartDataPoint]
    @State private var selectedPoint: ChartDataPoint?
    @State private var dragLocation: CGPoint = .zero
    
    private var isPositive: Bool {
        guard let first = data.first, let last = data.last else { return true }
        return last.value >= first.value
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(UIColor.secondarySystemBackground))
                
                // Chart
                if !data.isEmpty {
                    ChartPath(data: data, size: geometry.size)
                        .stroke(
                            isPositive ? WalletDesign.Colors.positiveChange : WalletDesign.Colors.negativeChange,
                            style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                        )
                        .padding(12)
                    
                    // Gradient Fill
                    ChartPath(data: data, size: geometry.size)
                        .fill(
                            LinearGradient(
                                colors: [
                                    (isPositive ? WalletDesign.Colors.positiveChange : WalletDesign.Colors.negativeChange).opacity(0.2),
                                    (isPositive ? WalletDesign.Colors.positiveChange : WalletDesign.Colors.negativeChange).opacity(0)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .padding(12)
                    
                    // Touch Indicator
                    if let selected = selectedPoint {
                        ChartTouchIndicator(
                            point: selected,
                            data: data,
                            size: geometry.size,
                            isPositive: isPositive
                        )
                    }
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        dragLocation = value.location
                        updateSelectedPoint(at: value.location, in: geometry.size)
                        HapticManager.selection()
                    }
                    .onEnded { _ in
                        withAnimation(.easeOut(duration: 0.2)) {
                            selectedPoint = nil
                        }
                    }
            )
        }
    }
    
    private func updateSelectedPoint(at location: CGPoint, in size: CGSize) {
        let xProgress = location.x / size.width
        let index = Int(xProgress * CGFloat(data.count))
        let clampedIndex = max(0, min(data.count - 1, index))
        
        withAnimation(.easeOut(duration: 0.1)) {
            selectedPoint = data[clampedIndex]
        }
    }
}

// MARK: - Chart Path
struct ChartPath: Shape {
    let data: [ChartDataPoint]
    let size: CGSize
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        guard !data.isEmpty else { return path }
        
        let minValue = data.map { $0.value }.min() ?? 0
        let maxValue = data.map { $0.value }.max() ?? 1
        let valueRange = maxValue - minValue
        
        let xStep = rect.width / CGFloat(data.count - 1)
        
        for (index, point) in data.enumerated() {
            let x = CGFloat(index) * xStep
            let yProgress = (point.value - minValue) / valueRange
            let y = rect.height * (1 - yProgress)
            
            if index == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        
        return path
    }
}

// MARK: - Chart Touch Indicator
struct ChartTouchIndicator: View {
    let point: ChartDataPoint
    let data: [ChartDataPoint]
    let size: CGSize
    let isPositive: Bool
    
    private var position: CGPoint {
        guard let index = data.firstIndex(where: { $0.id == point.id }) else { return .zero }
        
        let minValue = data.map { $0.value }.min() ?? 0
        let maxValue = data.map { $0.value }.max() ?? 1
        let valueRange = maxValue - minValue
        
        let xStep = (size.width - 24) / CGFloat(data.count - 1)
        let x = CGFloat(index) * xStep + 12
        
        let yProgress = (point.value - minValue) / valueRange
        let y = (size.height - 24) * (1 - yProgress) + 12
        
        return CGPoint(x: x, y: y)
    }
    
    var body: some View {
        ZStack {
            // Vertical Line
            Path { path in
                path.move(to: CGPoint(x: position.x, y: 12))
                path.addLine(to: CGPoint(x: position.x, y: size.height - 12))
            }
            .stroke(Color.primary.opacity(0.2), lineWidth: 1)
            
            // Point Circle
            Circle()
                .fill(isPositive ? WalletDesign.Colors.positiveChange : WalletDesign.Colors.negativeChange)
                .frame(width: 8, height: 8)
                .position(position)
            
            // Value Label
            Text(point.value.formatAsBalance())
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color(UIColor.secondarySystemBackground))
                        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                )
                .position(x: position.x, y: max(30, position.y - 20))
        }
    }
}

// MARK: - Chart Data Point
struct ChartDataPoint: Identifiable {
    let id = UUID()
    let time: Date
    let value: Double
}