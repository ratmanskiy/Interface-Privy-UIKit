//
//  ViewController.swift
//  Interface-Privy-UIKit
//
//  Created by User on 23.01.2025.
//

import UIKit
import PrivySDK

final class ViewController: UIViewController {
    fileprivate enum MyError: Error {
        case walletNotConnected
        case noEthereumWalletsAvailable
        case dataParseError
    }
    
    fileprivate struct QuoteResponse: Codable {
        struct QuoteData: Codable {
            struct TransactionData: Codable {
                let to: String
                let data: String
                let value: String
            }
            let transaction: TransactionData
        }
        let quoteData: QuoteData
    }
    
    private let stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 20
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private let emailField: UITextField = {
        let field = UITextField()
        field.placeholder = "Email"
        field.borderStyle = .roundedRect
        field.keyboardType = .emailAddress
        field.autocapitalizationType = .none
        return field
    }()
    
    private let sendCodeButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Send code", for: .normal)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 10
        return button
    }()
    
    private let codeField: UITextField = {
        let field = UITextField()
        field.placeholder = "Code"
        field.borderStyle = .roundedRect
        field.keyboardType = .numberPad
        return field
    }()
    
    private let verifyButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Verify email", for: .normal)
        button.backgroundColor = .systemGreen
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 10
        return button
    }()
    
    private let resultLabel: UILabel = {
        let label = UILabel()
        label.text = ""
        label.numberOfLines = 0
        label.textColor = UIColor.white
        return label
    }()
    
    private let personalSignButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Personal Sign", for: .normal)
        button.backgroundColor = .systemPurple
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 10
        return button
    }()
    
    private let transactionButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Send tranaction", for: .normal)
        button.backgroundColor = .systemPurple
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 10
        return button
    }()
    
    private var privy: Privy!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        initPrivy()
        
        setupUI()
        setupActions()
    }
    
    private func initPrivy() {
        print("Configuring Privy!")
        
        let config = PrivyConfig(
            appId: "cm6h8hqnv001jcacmv5g6w779",
            appClientId: "client-WY5gFSn13e5or7RthquPpZP1dHsEitCAkfWb74GNJzWEU"
        )
        
        let privy: Privy = PrivySdk.initialize(config: config)
        
        self.privy = privy
        
        privy.setAuthStateChangeCallback({ state in
            print(state)
        })
        
        privy.email.setOtpFlowStateChangeCallback({ state in
            print(state)
        })
        
        privy.embeddedWallet.setEmbeddedWalletStateChangeCallback({ state in
            print(state)
        })
    }
    
    private func configurePrivy() async {
        await privy.awaitReady()
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        view.addSubview(stackView)
        
        [emailField, sendCodeButton, codeField, verifyButton, personalSignButton].forEach {
            stackView.addArrangedSubview($0)
        }
        
        let spacerView = UIView()
        stackView.addArrangedSubview(spacerView)
        spacerView.setContentHuggingPriority(.defaultLow, for: .vertical)
        
        stackView.addArrangedSubview(resultLabel)
        stackView.addArrangedSubview(personalSignButton)
        stackView.addArrangedSubview(transactionButton)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            
            sendCodeButton.heightAnchor.constraint(equalToConstant: 44),
            verifyButton.heightAnchor.constraint(equalToConstant: 44),
            resultLabel.heightAnchor.constraint(equalToConstant: 44),
            personalSignButton.heightAnchor.constraint(equalToConstant: 44),
            transactionButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }
    
    private func setupActions() {
        sendCodeButton.addTarget(self, action: #selector(sendCodeTapped), for: .touchUpInside)
        verifyButton.addTarget(self, action: #selector(verifyCodeTapped), for: .touchUpInside)
        personalSignButton.addTarget(self, action: #selector(personalSignTapped), for: .touchUpInside)
        transactionButton.addTarget(self, action: #selector(sendTransactionTapped), for: .touchUpInside)
    }
    
    @objc private func sendCodeTapped() {
        guard let email = emailField.text,
              !email.isEmpty else {
            return
        }
        
        Task {
            await _ = privy.email.sendCode(to: email)
        }
    }
    
    @objc private func verifyCodeTapped() {
        guard let email = emailField.text,
              let code = codeField.text,
              !email.isEmpty,
              !code.isEmpty else {
            return
        }
        
        Task {
            do {
                try await _ = privy.email.loginWithCode(code, sentTo: email)
            } catch {
                print("privy.email.loginWithCode: \(error.localizedDescription)")
            }
        }
    }
    
    private let chainId = 8453
    private let sellToken = "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"
    private let sellAmount = 10000000000000
    private let buyToken = "0x0578d8a44db98b23bf096a382e016e29a5ce0ffe"
    
    @objc private func personalSignTapped() {
        Task {
            do {
                try await privy.embeddedWallet.connectWallet()
                
                guard case .connected(let wallets) = privy.embeddedWallet.embeddedWalletState else {
                    throw MyError.walletNotConnected
                }
                
                guard let wallet = wallets.first, wallet.chainType == .ethereum else {
                    throw MyError.noEthereumWalletsAvailable
                }
                
                let data = RpcRequest(method: "personal_sign", params: ["Hello Interface team!", wallet.address])
                let provider = try privy.embeddedWallet.getEthereumProvider(for: wallet.address)
                let response = try await provider.request(data)
                
                print("personal sign response: \(response)")
            } catch {
                print("personal sign error: \(error)")
            }
        }
    }
    
    @objc private func sendTransactionTapped() {
        Task {
            do {
                try await privy.embeddedWallet.connectWallet()
                
                guard case .connected(let wallets) = privy.embeddedWallet.embeddedWalletState else {
                    throw MyError.walletNotConnected
                }
                
                guard let wallet = wallets.first, wallet.chainType == .ethereum else {
                    throw MyError.noEthereumWalletsAvailable
                }
                
                let response = try await fetchQuote(userAddress: wallet.address)
                let transaction: [String: String?] = [
                    "to": response.quoteData.transaction.to,
                    "from": wallet.address,
                    "data": response.quoteData.transaction.data,
                    "value": response.quoteData.transaction.value.numberToHex(),
                    "chainId": Utils.toHexString(chainId)
                ]
                let txHash = try await send(userAddress: wallet.address,
                                            transaction: transaction)
                let result = "SUCCESS: \(txHash)"
                print(result)
                resultLabel.text = result
            } catch {
                let result = "FAILURE: \(error)"
                print(result)
                resultLabel.text = result
            }
        }
    }
    
    private func fetchQuote(userAddress: String) async throws -> QuoteResponse {
        let urlString = "https://tx.interface.social/swap/quote?user_address=\(userAddress)&chain_id=\(chainId)&sell_token=\(sellToken)&sell_amount=\(sellAmount)&buy_token=\(buyToken)&slippage_bps=100"
        
        print(urlString)
        guard let url = URL(string: urlString) else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        let config = URLSessionConfiguration.default
        config.urlCache = nil
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        
        let session = URLSession(configuration: config)
        
        let (data, _) = try await session.data(from: url)
        
        return try JSONDecoder().decode(QuoteResponse.self, from: data)
    }
    private func send(userAddress: String,
                      transaction: [String: String?]) async throws -> String {
        do {
            let txData = try JSONEncoder().encode(transaction)
            
            guard let txString = String(data: txData, encoding: .utf8) else {
                throw MyError.dataParseError
            }
            
            let provider = try privy.embeddedWallet.getEthereumProvider(for: userAddress)
            
            print("Request sent")
            print("Tx string: \(txString)")
            resultLabel.text = "Request sent"
            
            let transactionHash = try await provider.request(
                RpcRequest(
                    method: "eth_sendTransaction",
                    params: [txString]
                )
            )
            
            return transactionHash
        } catch {
            print("Send transaction error: \(error)")
            throw error
        }
    }
}

fileprivate extension String {
    func numberToHex() -> String? {
        guard let decimalValue = Decimal(string: self) else {
            return nil
        }
        let nsDecimal = NSDecimalNumber(decimal: decimalValue)
        
        guard let uint64Value = UInt64(nsDecimal.stringValue) else {
            return nil
        }
        
        return String(format: "0x%lX", uint64Value)
    }
}
