import CellyCore
import Combine
import SwiftUI

public struct AuthView: View {
    public class ViewModel: ObservableObject, Identifiable {
        @Published
        public var username = ""
        @Published
        public var password = ""

        @Published
        var isLoggedIn = false
        @Published
        var isLoading = false

        private let out: Out?; public typealias Out = (Command) -> Void; public enum Command {
            case forgotPassword
            case signin(String, String)
            case signup
            case support
        }

        fileprivate func signInAction() {
            self.out?(.signin(self.username, self.password))
        }

        fileprivate func signUpAction() {
            self.out?(.signup)
        }

        fileprivate func forgotAction() {
            self.out?(.forgotPassword)
        }

        fileprivate func supportAction() {
            self.out?(.support)
        }

        public init(_ out: Out? = nil) {
            self.out = out
        }
    }

    private let configuration: Configuration; public struct Configuration {
        public let mainColorDark: Color
        public let mainColorLight: Color
        public let textColor: Color
        public let placeholderColor: Color
        public let title: String
        public let username: String
        public let password: String
        public let signin: String
        public let signup: String
        public let forgot: String
        public let support: String
        public init(
            mainColorDark: Color = Color(UIColor(cgColor: CGColor.color(hex: "0077B5"))),
            mainColorLight: Color = Color(UIColor(cgColor: CGColor.color(hex: "1091D6"))),
            textColor: Color = Color(.darkText),
            placeholderColor: Color = Color(UIColor(cgColor: CGColor.color(hex: "cccccc"))),
            title: String,
            username: String,
            password: String,
            signin: String,
            signup: String,
            forgot: String,
            support: String
        ) {
            self.mainColorDark = mainColorDark
            self.mainColorLight = mainColorLight
            self.textColor = textColor
            self.placeholderColor = placeholderColor
            self.title = title
            self.username = username
            self.password = password
            self.signin = signin
            self.signup = signup
            self.forgot = forgot
            self.support = support
        }
    }

    @ObservedObject
    public var viewModel: ViewModel

    @State
    public var usernameFocused = false
    @State
    public var passwordFocused = false

    public init(configuration: Configuration, viewModel: ViewModel) {
        self.configuration = configuration
        self.viewModel = viewModel
    }

    public var body: some View {
        ZStack(alignment: .top) {
            Color(.white).edgesIgnoringSafeArea(.all)
            HStack {
                Image("tl")
                    .resizable()
                    .scaledToFill()
                    .edgesIgnoringSafeArea(.all)
                    .frame(width: 121.13, height: 90, alignment: .top)
                Spacer()
            }
            ZStack(alignment: .bottom) {
                VStack {
                    Spacer()
                    HStack {
                        Image("icon")
                            .resizable()
                            .frame(width: 40, height: 40, alignment: .center)
                            .aspectRatio(contentMode: .fit)
                        Text(self.configuration.title)
                            .font(.largeTitle)
                            .fontWeight(.semibold)
                            .foregroundColor(self.configuration.textColor)
                    }
                    .padding(.bottom, 20)
                    VStack(
                        alignment: .center,
                        spacing: /*@START_MENU_TOKEN@*/nil/*@END_MENU_TOKEN@*/
                    ) {
                        _TextField(
                            placeholder: Text(self.configuration.username)
                                .foregroundColor(self.configuration.placeholderColor),
                            text: self.$viewModel.username,
                            image: UIImage(systemName: "person.fill"),
                            editingChanged: { editing in
                                self.usernameFocused = editing
                            }
                        )
                        .foregroundColor(self.configuration.textColor)
                        .padding(EdgeInsets(top: 5, leading: 0, bottom: 10, trailing: 0))
                        .background(Color.white)
                        .padding(.bottom, 2.0)
                        .background(
                            self.usernameFocused ? self.configuration
                                .mainColorLight : self.configuration.placeholderColor
                        )
                        _SecureTextField(
                            placeholder: Text(self.configuration.password)
                                .foregroundColor(self.configuration.placeholderColor),
                            text: self.$viewModel.password,
                            image: UIImage(systemName: "lock.shield"),
                            editingChanged: { editing in
                                self.passwordFocused = editing
                            }
                        )
                        .foregroundColor(self.configuration.textColor)
                        .padding(EdgeInsets(top: 5, leading: 0, bottom: 10, trailing: 0))
                        .background(Color.white)
                        .padding(.bottom, 2.0)
                        .background(
                            self.passwordFocused ? self.configuration
                                .mainColorLight : self.configuration.placeholderColor
                        )
                    }
                    .padding(.horizontal, 32)
                    HStack {
                        Spacer()
                        _MinorButton(
                            text: self.configuration.forgot,
                            action: self.viewModel.forgotAction
                        )
                        .foregroundColor(self.configuration.placeholderColor)
                    }
                    .padding(.top, 0)
                    .padding(.horizontal, 32)
                    Button(action: self.viewModel.signInAction) {
                        Text(self.configuration.signin.localizedUppercase)
                            .font(.headline)
                            .foregroundColor(Color(.white))
                            .padding()
                    }
                    .frame(
                        maxWidth: /*@START_MENU_TOKEN@*/ .infinity/*@END_MENU_TOKEN@*/,
                        alignment: /*@START_MENU_TOKEN@*/ .center/*@END_MENU_TOKEN@*/
                    )
                    .background(
                        self.viewModel.username.isEmpty || self.viewModel.password
                            .isEmpty ? self.configuration.placeholderColor : self.configuration.mainColorLight
                    )
                    .cornerRadius(8.0)
                    .padding(.horizontal, 32)
                    .padding(.top, 20)
                    .disabled(self.viewModel.username.isEmpty || self.viewModel.password.isEmpty)
                    Spacer()
                    _MajorButton(
                        text: self.configuration.signup,
                        action: self.viewModel.signUpAction
                    )
                    .padding(.bottom, 0)
                    _MinorButton(
                        text: self.configuration.support,
                        action: self.viewModel.supportAction
                    )
                    .foregroundColor(self.configuration.textColor)
                    .padding(.bottom, 80)
                    Spacer()
                }
                HStack {
                    Spacer()
                    Image("br")
                        .resizable()
                        .edgesIgnoringSafeArea(.all)
                        .frame(width: 240, height: 180, alignment: .bottom)
                        .allowsHitTesting(false)
                }
                .allowsTightening(false)
            }
        }.onTapGesture {
            self.endEditing()
        }
    }

    private func endEditing() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
}

private struct _MajorButton: View {
    let text: String
    let action: () -> Void
    var body: some View {
        Button(action: self.action) {
            Text(self.text.localizedUppercase)
                .font(.headline)
                .foregroundColor(Color(.darkText))
                .padding()
        }
        .frame(
            maxWidth: /*@START_MENU_TOKEN@*/ .infinity/*@END_MENU_TOKEN@*/,
            alignment: /*@START_MENU_TOKEN@*/ .center/*@END_MENU_TOKEN@*/
        )
        .cornerRadius(8.0)
        .padding(.horizontal, 16)
    }
}

private struct _MinorButton: View {
    let text: String
    let action: () -> Void
    var body: some View {
        Button(action: self.action) {
            Text(self.text)
                .font(.body)
        }
    }
}

private struct _TextField: View {
    var placeholder: Text
    @Binding
    var text: String
    var image: UIImage?
    var editingChanged: (Bool) -> Void = { _ in }
    var commit: () -> Void = {}

    var body: some View {
        HStack {
            if let image = self.image {
                Image(uiImage: image)
                    .resizable()
                    .frame(width: 12.0, height: 12.0)
                    .padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 5))
            }
            ZStack(alignment: .leading) {
                if self.text.isEmpty { self.placeholder }
                TextField("", text: self.$text, onEditingChanged: self.editingChanged, onCommit: self.commit)
            }
        }
    }
}

private struct _SecureTextField: View {
    var placeholder: Text
    @Binding
    var text: String
    var image: UIImage?
    var editingChanged: (Bool) -> Void = { _ in }
    var commit: () -> Void = {}
    var body: some View {
        HStack {
            if let image = self.image {
                Image(uiImage: image)
                    .resizable()
                    .frame(width: 12.0, height: 14.0)
                    .padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 5))
            }
            ZStack(alignment: .leading) {
                if self.text.isEmpty { self.placeholder }
                SecureField("", text: self.$text)
            }
        }
    }
}

#if DEBUG
    struct SignInView_Previews: PreviewProvider {
        static var previews: some View {
            Group {
                let configuration = AuthView.Configuration(
                    title: "Celly.AI",
                    username: "Username",
                    password: "Password",
                    signin: "Sign in",
                    signup: "Create Account",
                    forgot: "Forgot password",
                    support: "Support"
                )
                AuthView(configuration: configuration, viewModel: .init())
                    .preferredColorScheme(.dark)
                    .previewDevice(PreviewDevice(rawValue: "iPhone XS"))
                    .previewDisplayName("iPhone XS")
                AuthView(configuration: configuration, viewModel: .init())
                    .preferredColorScheme(.light)
                    .previewDevice(PreviewDevice(rawValue: "iPhone XS Max"))
                    .previewDisplayName("iPhone XS Max")
                AuthView(configuration: configuration, viewModel: .init())
                    .preferredColorScheme(.light)
                    .previewDevice(PreviewDevice(rawValue: "iPhone 8"))
                    .previewDisplayName("iPhone 8")
            }
        }
    }
#endif
