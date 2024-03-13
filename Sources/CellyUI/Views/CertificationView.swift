import Foundation
import SwiftUI

public struct CertificationView: View {
    private let strings: Strings; public struct Strings {
        public init(title: String, description: String, footer: String) {
            self.title = title
            self.description = description
            self.footer = footer
        }

        let title: String
        let description: String
        let footer: String
    }

    public init(strings: Strings) {
        self.strings = strings
    }

    public var body: some View {
        VStack(alignment: .leading) {
            Text(self.strings.title)
                .fontWeight(.bold)
                .lineLimit(5)

            HStack(alignment: .top) {
                Image("certification_1", bundle: .module)
                    .resizable()
                    .frame(width: 100, height: 100)
                    .background(Color.gray)
                Spacer()
                VStack(alignment: .leading, spacing: 4) {
                    Text(self.strings.description)
                }
                .font(Font.system(size: 11))
                Spacer()
                Image("certification_2", bundle: .module)
                    .resizable()
                    .frame(width: 100, height: 100)
                    .background(Color.gray)
            }

            // Description Text
            Text(self.strings.footer)
                .font(Font.system(size: 8))
                .padding(.top, 8)

            //            HStack(alignment: /*@START_MENU_TOKEN@*/.center/*@END_MENU_TOKEN@*/) {
            //                Spacer()
            //                Button(action: {}, label: {
            //                    Text("Close")
            //                })
            //                Button(action: {}, label: {
            //                    Text("Support")
            //                })
            //                Spacer()
            //            }
            //            .padding(.top, 16)
        }
        .padding()
    }
}

private struct CertificationView_Previews: PreviewProvider {
    static var previews: some View {
        let title = "Celly Automated Microscope"
        let description = """
        Celly.AI Corporation
        440 N Barranca Ave #1951 Covina, CA 91723
        Tel: +90-534-416-84-15
        Email: hello@celly.ai\n\n
        AFINA s.r.o. Kaprova 42/14 110 00, Prague, Czech Republic
        Tel: +420608049029
        Email: info@getce.eu
        """
        let footer = """
        Intended use of Celly Automated Microscope (CAM)
        CAM is an automated cell-locating device intended for in-vitro diagnostic use in clinical laboratories. CAM is intended for differential count of white blood cells (WBC), evaluation of red blood cell (RBC) morphology and platelet estimation. Device automatically locates blood cells on peripheral blood (PB) smears. Application presents images of the blood cells for review. A skilled operator trained in recognition of blood cells, identifies and verifies the suggested classification of each cell according to type.
        """
        CertificationView(strings: .init(
            title: title,
            description: description,
            footer: footer
        ))
    }
}
