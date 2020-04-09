//
//  InAppPurchaseView.swift
//  3Dify
//
//  Created by It's free real estate on 06.04.20.
//  Copyright © 2020 Philipp Matthes. All rights reserved.
//

import SwiftUI
import StoreKit


enum InAppPurchaseOrchestratorError {
    case transactionFailed
    case loadProductFailed
    case unknown
}


class InAppPurchaseOrchestrator: NSObject, ObservableObject {
    public var onUnlocked: (() -> ())
    public var onFailed: ((InAppPurchaseOrchestratorError) -> ())
    
    private var onLoadProduct: ((SKProduct) -> ())?
    
    init(onUnlocked: @escaping () -> (), onFailed: @escaping (InAppPurchaseOrchestratorError) -> ()) {
        self.onUnlocked = onUnlocked
        self.onFailed = onFailed
        super.init()
        
        SKPaymentQueue.default().add(self)
    }
    
    deinit {
        SKPaymentQueue.default().remove(self)
    }
    
    static var isProductUnlocked: Bool {
        get {
            return (UserDefaults.standard.object(forKey: "isProductUnlocked") as? Bool) ?? false
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "isProductUnlocked")
        }
    }
}


// MARK: - Load Product
extension InAppPurchaseOrchestrator: SKProductsRequestDelegate {
    public func loadProduct(completion: @escaping (SKProduct) -> ()) {
        self.onLoadProduct = completion
        let request = SKProductsRequest(
            productIdentifiers: Set(["remove_watermark"])
        )
        request.delegate = self
        request.start()
    }
    
    internal func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        if let product = response.products.first {
            onLoadProduct?(product)
        } else {
            onFailed(.loadProductFailed)
        }
    }
    
    internal func request(_ request: SKRequest, didFailWithError error: Error) {
        onFailed(.loadProductFailed)
    }
}


// MARK: - Make Purchase
extension InAppPurchaseOrchestrator {
    public func purchase(product: SKProduct) {
        guard SKPaymentQueue.canMakePayments() else {
            onFailed(.transactionFailed)
            return
        }
        let payment = SKPayment(product: product)
        SKPaymentQueue.default().add(payment)
    }
}


// MARK: - Restore Purchase
extension InAppPurchaseOrchestrator: SKPaymentTransactionObserver {
    public func restorePurchases() {
        SKPaymentQueue.default().restoreCompletedTransactions()
    }
    
    internal func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        for transaction in transactions {
            switch transaction.transactionState {
            case .purchased:
                Self.isProductUnlocked = true
                self.onUnlocked()
                queue.finishTransaction(transaction)
            case .restored:
                Self.isProductUnlocked = true
                self.onUnlocked()
                queue.finishTransaction(transaction)
            case .failed:
                self.onFailed(.transactionFailed)
                queue.finishTransaction(transaction)
            case .purchasing:
                break
            case .deferred:
                break
            @unknown default:
                self.onFailed(.unknown)
                queue.finishTransaction(transaction)
            }
        }
    }
}


protocol InAppPurchase {
    var localizedDescription: String { get }
    var localizedTitle: String { get }
    var price: NSDecimalNumber { get }
    var priceLocale: Locale { get }
    var productIdentifier: String { get }
    var isDownloadable: Bool { get }
    var downloadContentLengths: [NSNumber] { get }
    var contentVersion: String { get }
    var downloadContentVersion: String { get }
    var subscriptionPeriod: SKProductSubscriptionPeriod? { get }
    var introductoryPrice: SKProductDiscount? { get }
    var subscriptionGroupIdentifier: String? { get }
    var discounts: [SKProductDiscount] { get }
}

extension SKProduct: InAppPurchase {}


internal extension InAppPurchase {
    var localizedPrice: String {
        if self.price == 0.00 {
            return "Free"
        } else {
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.locale = self.priceLocale
            
            guard let formattedPrice = formatter.string(from: price) else {
                return "Unkown price"
            }
            
            return formattedPrice
        }
    }
}


struct InAppPurchaseView: View {
    @EnvironmentObject public var orchestrator: InAppPurchaseOrchestrator
    
    @State var product: InAppPurchase?
    
    @State var loadingText = "Loading Store..."
    @State var loadingState: LoadingState = .loading
    
    @State var purchaseButtonScale: CGFloat = 1
    
    var purchaseButtonAnimation: Animation {
        Animation
        .easeInOut(duration: 1)
        .repeatForever(autoreverses: true)
    }
    
    var body: some View {
        GeometryReader { geometry in
            LoadingView(text: self.$loadingText, loadingState: self.$loadingState) {
                VStack {
                    Spacer()
                    
                    VStack(alignment: .center) {
                        Spacer()
                        LinearGradient(
                            gradient: Gradients.learningLeading,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .mask(HStack {
                            Spacer()
                            Text("For the pros!")
                            .font(.largeTitle)
                            .fontWeight(.heavy)
                            Spacer()
                        })
                        .frame(height: 48)
                        Text("Buy the developer a ☕ and remove the \"Made with 3Dify\" watermark on your videos!")
                        .fixedSize(horizontal: false, vertical: true)
                        Spacer()
                    }
                    .padding(24)
                    .multilineTextAlignment(.center)
                    
                    VStack {
                        if self.product != nil {
                            Button(action: {
                                guard let product = self.product as? SKProduct else {
                                    print("Purchasing with Debug Product is not possible!")
                                    return
                                }
                                self.loadingState = .loading
                                self.loadingText = "Purchasing..."
                                self.orchestrator.purchase(product: product)
                            }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(self.product!.localizedTitle)
                                        .fixedSize(horizontal: false, vertical: true)
                                        Text(self.product!.localizedDescription)
                                        .font(.caption)
                                        .opacity(0.5)
                                        .fixedSize(horizontal: false, vertical: true)
                                        Text(self.product!.localizedPrice)
                                        .foregroundColor(Color.green)
                                    }
                                    .padding(.leading, 12)
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                    .padding(12)
                                }
                                .foregroundColor(.black)
                            }
                            .scaleEffect(self.purchaseButtonScale)
                            .onAppear() {
                                withAnimation(self.purchaseButtonAnimation) {
                                    self.purchaseButtonScale = 1.03
                                }
                            }
                            .buttonStyle(FatButtonStyle(cornerRadius: 32))
                        }
                        
                        HStack {
                            Spacer()
                            Capsule().frame(width: 32, height: 1)
                            Text("OR").font(.caption)
                            Capsule().frame(width: 32, height: 1)
                            Spacer()
                        }
                        .opacity(0.5)
                        .foregroundColor(.white)
                        
                        Button(action: {
                            self.loadingState = .loading
                            self.loadingText = "Restoring..."
                            self.orchestrator.restorePurchases()
                        }) {
                            Text("Restore purchases")
                            .foregroundColor(.white)
                        }
                        .buttonStyle(OutlinedFatButtonStyle())
                        .padding(.bottom, geometry.safeAreaInsets.bottom)
                    }
                    .transition(.move(edge: .bottom))
                    .padding(12)
                    .background(LinearGradient(gradient: Gradients.learningLeading, startPoint: .topLeading, endPoint: .bottomTrailing))
                }
            }
            .onAppear() {
                self.orchestrator.loadProduct() { product in
                    self.loadingState = .hidden
                    self.product = product
                }
            }
            .background(LinearGradient(gradient: Gradients.clouds, startPoint: .topLeading, endPoint: .bottomTrailing))
            .foregroundColor(Color.black)
            .edgesIgnoringSafeArea(.vertical)
        }
    }
}


class PreviewInAppPurchase: InAppPurchase {
    var localizedDescription: String = "Remove the \"Made with 3Dify\" Watermark"
    var localizedTitle: String = "Remove Watermark"
    var price: NSDecimalNumber = 3.49
    var priceLocale: Locale = .init(identifier: "de_DE")
    var productIdentifier: String = "remove_watermark"
    var isDownloadable: Bool = false
    var downloadContentLengths: [NSNumber] = []
    var contentVersion: String = "Debug"
    var downloadContentVersion: String = "Debug"
    var subscriptionPeriod: SKProductSubscriptionPeriod? = nil
    var introductoryPrice: SKProductDiscount? = nil
    var subscriptionGroupIdentifier: String? = nil
    var discounts: [SKProductDiscount] = []
}


struct InAppPurchaseView_Previews: PreviewProvider {
    static var previews: some View {
        InAppPurchaseView(product: PreviewInAppPurchase()).environmentObject(InAppPurchaseOrchestrator(onUnlocked: {}, onFailed: { error in
            print(error)
        }))
    }
}
