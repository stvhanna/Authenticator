//
//  AppModel.swift
//  Authenticator
//
//  Copyright (c) 2015 Authenticator authors
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//

import UIKit

class AppModel {
    weak var presenter: AppPresenter?

    private lazy var tokenStore: TokenStore = {
        let tokenStore = TokenStore(actionHandler: self)
        tokenStore.presenter = self
        return tokenStore
    }()
    private var tokenList: TokenList {
        return TokenList(tokenStore: tokenStore)
    }

    private var modalState: ModalState {
        didSet {
            presenter?.updateWithViewModel(viewModel)
        }
    }

    private enum ModalState {
        case None
        case EntryScanner
        case EntryForm(TokenEntryForm)
        case EditForm(TokenEditForm)
    }

    init() {
        modalState = .None
    }

    var viewModel: AppViewModel {
        let modal: AppViewModel.Modal
        switch modalState {
        case .None:
            modal = .None
        case .EntryScanner:
            modal = .Scanner
        case .EntryForm(let form):
            modal = .EntryForm(form.viewModel)
        case .EditForm(let form):
            modal = .EditForm(form.viewModel)
        }

        return AppViewModel(
            tokenList: tokenList.viewModel,
            modal: modal
        )
    }
}

extension AppModel: TokenListPresenter {
    func update() {
        presenter?.updateWithViewModel(self.viewModel)
    }
}

extension AppModel: ActionHandler {
    func handleAction(action: AppAction) {
        switch action {
        case .BeginTokenEntry:
            guard QRScanner.deviceCanScan else {
                handleAction(.BeginManualTokenEntry)
                break
            }
            modalState = .EntryScanner

        case .BeginManualTokenEntry:
            let form = TokenEntryForm()
            modalState = .EntryForm(form)

        case .SaveNewToken(let token):
            tokenStore.addToken(token)
            modalState = .None

        case .CancelTokenEntry:
            modalState = .None

        case .BeginTokenEdit(let persistentToken):
            let form = TokenEditForm(persistentToken: persistentToken)
            modalState = .EditForm(form)

        case let .SaveChanges(token, persistentToken):
            tokenStore.saveToken(token, toPersistentToken: persistentToken)
            modalState = .None

        case .CancelTokenEdit:
            modalState = .None

        case .AddTokenFromURL(let token):
            tokenStore.addToken(token)

        case .TokenListAction(let action):
            tokenStore.handleAction(action)

        case .TokenEntryFormAction(let action):
            if case .EntryForm(let form) = modalState {
                var newForm = form
                let resultingAppAction = newForm.handleAction(action)
                modalState = .EntryForm(newForm)
                // Handle the resulting action after committing the changes of the initial action
                if let resultingAppAction = resultingAppAction {
                    handleAction(resultingAppAction)
                }
            }

        case .TokenEditFormAction(let action):
            if case .EditForm(let form) = modalState {
                var newForm = form
                let resultingAppAction = newForm.handleAction(action)
                modalState = .EditForm(newForm)
                // Handle the resulting action after committing the changes of the initial action
                if let resultingAppAction = resultingAppAction {
                    handleAction(resultingAppAction)
                }
            }
        }
    }
}
