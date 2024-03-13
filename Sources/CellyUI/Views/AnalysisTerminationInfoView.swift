import SwiftUI

// TODO: L10n
// 1) https://developer.apple.com/documentation/xcode/localizing-package-resources
// 2) https://forums.swift.org/t/swift-package-manager-localization/46685

public struct AnalysisTerminationInfoListView: View {
    public let infos: [AnalysisTerminationInfoView]
    public var complete: () -> Void
    public let strings: Strings
    public init(
        infos: [AnalysisTerminationInfoView],
        complete: @escaping () -> Void,
        strings: Strings = .init()
    ) {
        self.infos = infos
        self.complete = complete
        self.strings = strings
    }

    public struct Strings {
        let title: String
        let slide: String
        let id: String
        let duration: String
        let result: String
        let objects: String
        let completeTitle: String
        public init(
            title: String = "Tests completed",
            slide: String = "#",
            id: String = "Id",
            duration: String = "Duration (min)",
            result: String = "Result",
            objects: String = "Objects",
            completeTitle: String = "Close"
        ) {
            self.title = title
            self.slide = slide
            self.id = id
            self.duration = duration
            self.result = result
            self.objects = objects
            self.completeTitle = completeTitle
        }
    }

    public var body: some View {
        List {
            HStack(alignment: .center) {
                Spacer()
                Text(strings.title)
                Spacer()
            }
            HStack(alignment: .center) {
                _HeaderText(strings.slide).frame(width: 20)
                Divider()
                _HeaderText(strings.id).frame(width: 50)
                Divider()
                _HeaderText(strings.duration).frame(width: 80)
                Divider()
                _HeaderText(strings.result, spaceBetween: true)
                Divider()
                _HeaderText(strings.objects).frame(width: 50)
            }
            ForEach(infos) { data in
                data.listRowSeparator(.hidden)
            }
            Spacer()
            HStack(alignment: .center) {
                Spacer()
                Button(action: complete) {
                    Text(strings.completeTitle)
                }
                Spacer()
            }
        }
    }
}

public struct AnalysisTerminationInfoView: View, Identifiable {
    public let slide: String
    public let id: String
    public let duration: String
    public let reason: String
    public let objectsCount: Int?
    public let backgroundColor: Color

    public init(
        slide: String,
        id: String,
        duration: String,
        reason: String,
        objectsCount: Int?,
        backgroundColor: Color
    ) {
        self.slide = slide
        self.id = id
        self.duration = duration
        self.reason = reason
        self.objectsCount = objectsCount
        self.backgroundColor = backgroundColor
    }

    public var body: some View {
        HStack(alignment: .center) {
            _CellText(slide).frame(width: 20)
            Divider()
            _CellText(id).frame(width: 50)
            Divider()
            _CellText(duration).frame(width: 80)
            Divider()
            _CellText(reason, spaceBetween: true)
            Divider()
            _CellText(objectsCount.map { "\($0)" } ?? "0").frame(width: 50)
        }
        .padding(.vertical)
        .background(backgroundColor)
    }
}

struct _HeaderText: View {
    @State
    var content: String
    var spaceBetween: Bool
    public init(_ content: String, spaceBetween: Bool = false) {
        self.content = content
        self.spaceBetween = spaceBetween
    }

    public var body: some View {
        if spaceBetween {
            Spacer()
        }
        Text(content).font(.caption).frame(alignment: .center)
        if spaceBetween {
            Spacer()
        }
    }
}

struct _CellText: View {
    @State
    var content: String
    var spaceBetween: Bool
    public init(_ content: String, spaceBetween: Bool = false) {
        self.content = content
        self.spaceBetween = spaceBetween
    }

    public var body: some View {
        if spaceBetween {
            Spacer()
        }
        Text(content).font(.caption).frame(alignment: .center)
        if spaceBetween {
            Spacer()
        }
    }
}

struct AnalysisTerminationInfoView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            AnalysisTerminationInfoListView(
                infos:
                [
                    AnalysisTerminationInfoView(
                        slide: "1",
                        id: "216821",
                        duration: "1",
                        reason: "Reason long description",
                        objectsCount: 13,
                        backgroundColor: Color.indigo
                    ),
                    AnalysisTerminationInfoView(
                        slide: "2",
                        id: "21682",
                        duration: "1",
                        reason: "Reason",
                        objectsCount: 13,
                        backgroundColor: Color.orange
                    ),
                    AnalysisTerminationInfoView(
                        slide: "3",
                        id: "21683",
                        duration: "1",
                        reason: "Reason",
                        objectsCount: 13,
                        backgroundColor: Color.pink
                    ),
                    AnalysisTerminationInfoView(
                        slide: "4",
                        id: "21684",
                        duration: "1",
                        reason: "Reason",
                        objectsCount: 13,
                        backgroundColor: Color.yellow
                    ),
                    AnalysisTerminationInfoView(
                        slide: "5",
                        id: "21685",
                        duration: "1",
                        reason: "Reason",
                        objectsCount: 13,
                        backgroundColor: Color.red
                    ),
                    AnalysisTerminationInfoView(
                        slide: "6",
                        id: "21686",
                        duration: "1",
                        reason: "Reason",
                        objectsCount: 13,
                        backgroundColor: Color.clear
                    ),
                ]
            ) {
                print("Complete")
            }
            .preferredColorScheme(.light)
            .environment(\.sizeCategory, .large)
            .previewInterfaceOrientation(.landscapeLeft)
            AnalysisTerminationInfoListView(
                infos:
                [
                    AnalysisTerminationInfoView(
                        slide: "1",
                        id: "216821",
                        duration: "1",
                        reason: "Reason long description",
                        objectsCount: 13,
                        backgroundColor: Color.indigo
                    ),
                    AnalysisTerminationInfoView(
                        slide: "2",
                        id: "21682",
                        duration: "1",
                        reason: "Reason",
                        objectsCount: 13,
                        backgroundColor: Color.orange
                    ),
                    AnalysisTerminationInfoView(
                        slide: "3",
                        id: "21683",
                        duration: "1",
                        reason: "Reason",
                        objectsCount: 13,
                        backgroundColor: Color.pink
                    ),
                    AnalysisTerminationInfoView(
                        slide: "4",
                        id: "21684",
                        duration: "1",
                        reason: "Reason",
                        objectsCount: 13,
                        backgroundColor: Color.yellow
                    ),
                    AnalysisTerminationInfoView(
                        slide: "5",
                        id: "21685",
                        duration: "1",
                        reason: "Reason",
                        objectsCount: 13,
                        backgroundColor: Color.red
                    ),
                    AnalysisTerminationInfoView(
                        slide: "6",
                        id: "21686",
                        duration: "1",
                        reason: "Reason",
                        objectsCount: 13,
                        backgroundColor: Color.clear
                    ),
                ]
            ) {
                print("Complete")
            }
            .preferredColorScheme(.light)
            .environment(\.sizeCategory, .large)
            .previewInterfaceOrientation(.portraitUpsideDown)
        }
    }
}
