//
//  ArtPipelineProgress.swift
//  XRoads
//
//  Created by Nexus on 2026-02-04.
//  US-V4-027: Progress tracker component for Art Direction pipeline steps
//

import SwiftUI

// MARK: - Pipeline Progress View

struct ArtPipelineProgress: View {
    @Binding var currentStep: ArtPipelineStep
    let stepStatuses: [ArtPipelineStep: ArtPipelineStepStatus]
    let onStepSelected: (ArtPipelineStep) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(ArtPipelineStep.allCases, id: \.self) { step in
                stepView(for: step)

                if step.rawValue < ArtPipelineStep.allCases.count - 1 {
                    connector(from: step)
                }
            }
        }
        .padding(Theme.Spacing.md)
        .background(Color.bgSurface)
        .cornerRadius(Theme.Radius.lg)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg)
                .stroke(Color.borderDefault, lineWidth: 1)
        )
    }

    // MARK: - Step View

    private func stepView(for step: ArtPipelineStep) -> some View {
        let status = stepStatuses[step] ?? .pending
        let isSelected = step == currentStep

        return Button {
            onStepSelected(step)
        } label: {
            VStack(spacing: Theme.Spacing.xs) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.accentPrimary.opacity(0.15) : Color.clear)
                        .frame(width: 44, height: 44)

                    Circle()
                        .stroke(status.color, lineWidth: isSelected ? 2 : 1)
                        .frame(width: 36, height: 36)

                    Image(systemName: statusIcon(for: status, step: step))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(status.color)
                }

                Text(step.title)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? Color.textPrimary : Color.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(width: 80)
            }
        }
        .buttonStyle(.plain)
    }

    private func statusIcon(for status: ArtPipelineStepStatus, step: ArtPipelineStep) -> String {
        switch status {
        case .completed:
            return "checkmark"
        case .inProgress:
            return step.iconName
        case .error:
            return "xmark"
        case .pending:
            return step.iconName
        }
    }

    // MARK: - Connector

    private func connector(from step: ArtPipelineStep) -> some View {
        let currentStatus = stepStatuses[step] ?? .pending
        let nextStep = step.next
        let nextStatus = nextStep.flatMap { stepStatuses[$0] } ?? .pending

        let isActive = currentStatus == .completed

        return Rectangle()
            .fill(isActive ? Color.statusSuccess : Color.borderMuted)
            .frame(height: 2)
            .frame(maxWidth: .infinity)
            .padding(.bottom, 24)
    }
}

// MARK: - Compact Progress Indicator

struct ArtPipelineProgressCompact: View {
    let currentStep: ArtPipelineStep
    let stepStatuses: [ArtPipelineStep: ArtPipelineStepStatus]

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            ForEach(ArtPipelineStep.allCases, id: \.self) { step in
                let status = stepStatuses[step] ?? .pending
                let isCurrent = step == currentStep

                Circle()
                    .fill(status == .completed ? Color.statusSuccess : (isCurrent ? Color.accentPrimary : Color.borderMuted))
                    .frame(width: isCurrent ? 10 : 8, height: isCurrent ? 10 : 8)
                    .animation(.easeInOut(duration: 0.2), value: isCurrent)
            }
        }
    }
}

// MARK: - Step Detail Card

struct ArtPipelineStepCard: View {
    let step: ArtPipelineStep
    let status: ArtPipelineStepStatus
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Theme.Spacing.md) {
                ZStack {
                    Circle()
                        .fill(status.color.opacity(0.15))
                        .frame(width: 40, height: 40)

                    Image(systemName: status == .completed ? "checkmark" : step.iconName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(status.color)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(step.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)

                    Text(step.subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                if status == .inProgress {
                    ProgressView()
                        .controlSize(.small)
                } else if isSelected {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.accentPrimary)
                }
            }
            .padding(Theme.Spacing.md)
            .background(isSelected ? Color.accentPrimary.opacity(0.08) : Color.bgSurface)
            .cornerRadius(Theme.Radius.md)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.md)
                    .stroke(isSelected ? Color.accentPrimary : Color.borderDefault, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#if DEBUG
struct ArtPipelineProgress_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: Theme.Spacing.lg) {
            ArtPipelineProgress(
                currentStep: .constant(.generatePRD),
                stepStatuses: [
                    .createBible: .completed,
                    .generatePRD: .inProgress,
                    .runLoop: .pending,
                    .viewComponents: .pending
                ],
                onStepSelected: { _ in }
            )

            ArtPipelineProgressCompact(
                currentStep: .generatePRD,
                stepStatuses: [
                    .createBible: .completed,
                    .generatePRD: .inProgress,
                    .runLoop: .pending,
                    .viewComponents: .pending
                ]
            )

            ArtPipelineStepCard(
                step: .createBible,
                status: .completed,
                isSelected: false,
                onTap: {}
            )

            ArtPipelineStepCard(
                step: .generatePRD,
                status: .inProgress,
                isSelected: true,
                onTap: {}
            )
        }
        .padding()
        .background(Color.bgApp)
        .frame(width: 600, height: 400)
    }
}
#endif
