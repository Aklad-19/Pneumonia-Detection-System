import 'package:flutter/material.dart';
import 'package:flutter_sslcommerz/model/SSLCSdkType.dart';
import 'package:flutter_sslcommerz/model/SSLCommerzInitialization.dart';
import 'package:flutter_sslcommerz/model/SSLCurrencyType.dart';
import 'package:flutter_sslcommerz/sslcommerz.dart';

/// Handles the payment logic for SSLCommerz.
/// Replace the `_fakeSslCommerzPayment()` section with your real SSLCommerz integration.
Future<void> onButtonTap(BuildContext context, String selected) async {
  if (selected != 'sslcommerz') {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Currently only SSLCommerz is available for payment.'),
      ),
    );
    return;
  }
  double totalPrice = 500.0;

  try {
    // -------------------------------------------------------------------------
    // 🔧 TODO: Integrate your SSLCommerz payment here
    //
    // Example (using ssl_commerz_flutter package):
    //
    // import 'package:ssl_commerz_flutter/ssl_commerz_flutter.dart';
    //
    Sslcommerz sslcommerz = Sslcommerz(
        initializer: SSLCommerzInitialization(
          //   ipn_url: "www.ipnurl.com",
            multi_card_name: "visa,master,bkash",
            currency: SSLCurrencyType.BDT,
            product_category: "Donation",
            sdkType: SSLCSdkType.TESTBOX,
            store_id: "chowd690e16bc04715",
            store_passwd: "chowd690e16bc04715@ssl",
            total_amount: totalPrice,
            tran_id: "custom_transaction_id"));

     var result = await sslcommerz.payNow();

     if (result.status == "VALID") {
        print("Payment Successful");
     } else {
       // payment failed
     }
    // -------------------------------------------------------------------------

    final bool paymentSuccess = await _fakeSslCommerzPayment(context);

    if (paymentSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment successful! Thank you for your donation.'),
        ),
      );

      // Return to previous page with success result
      Navigator.pop<bool>(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment failed or cancelled.'),
        ),
      );
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error during payment: $e')),
    );
  }
}

/// Temporary fake payment (simulate success/failure)
Future<bool> _fakeSslCommerzPayment(BuildContext context) async {
  await Future.delayed(const Duration(seconds: 2));
  return true; // change to false to simulate failure
}
