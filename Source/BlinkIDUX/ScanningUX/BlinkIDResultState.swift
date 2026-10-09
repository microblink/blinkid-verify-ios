//
//  BlinkIDResultState.swift
//  DocumentVerificationUX
//
//  Created by Jura Skrlec on 19.02.2025..
//


#if BLINKIDVERIFYUX
import BlinkIDVerify
#elseif BLINKIDUX
import BlinkID
#endif

public struct BlinkIDResultState {
    public let scanningResult: BlinkIDScanningResult?
}
