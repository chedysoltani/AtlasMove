import 'package:atlasmove/models/driver_subscription_models.dart';
import 'package:flutter_test/flutter_test.dart';

PrivilegeReward _reward(Map<String, dynamic> json) =>
    PrivilegeReward.fromJson({'id': 'r', 'type': 'cashback', ...json});

void main() {
  group('PrivilegeReward.isSubscriptionReward', () {
    test('billing_model du backend prioritaire', () {
      expect(_reward({'title': 'Cashback 50%', 'billing_model': 'commission'}).isSubscriptionReward, isFalse);
      expect(_reward({'title': 'Bonus', 'billing_model': 'subscription_plus_rate'}).isSubscriptionReward, isTrue);
    });

    test("sans billing_model : cashback 50 % / abonnement = offre Taxi Économique", () {
      expect(_reward({'title': 'Cashback 50 % sur votre abonnement'}).isSubscriptionReward, isTrue);
      expect(_reward({'title': 'Cashback 50%'}).isSubscriptionReward, isTrue);
    });

    test('le cashback 3 % sur les commissions reste visible', () {
      expect(_reward({'title': 'Cashback 3% sur les commissions'}).isSubscriptionReward, isFalse);
    });
  });
}
