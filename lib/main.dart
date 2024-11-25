import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart'; // Import firebase_core
import 'firebase_options.dart'; // Import firebase_options.dart
import 'utils/app_localizations.dart';
import 'screens/welcome_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'theme/app_theme.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'screens/splash_screen.dart';
import 'screens/merchant_home_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:demo/screens/merchant_add.dart';
import 'screens/merchant_items.dart';
import 'package:demo/screens/merchant_edit.dart';
import 'package:demo/screens/item_details.dart';
import 'package:demo/screens/browse_screen.dart';
import 'package:demo/screens/profile_screen.dart';
import 'package:demo/screens/chat_screen.dart';
import 'package:demo/screens/cart_screen.dart';
import 'package:demo/screens/favorites_screen.dart';
import 'package:demo/screens/orders_screen.dart';
import 'package:demo/screens/merchant_orders_screen.dart';
import 'package:demo/screens/visa_screen.dart';
import 'screens/services_home_page.dart';
import 'screens/visa_request_screen.dart';
import 'screens/visa_inquiry_screen.dart';
import 'screens/museums_screen.dart';
import 'screens/museums_reservation_screen.dart';
import 'screens/museums_inquiry_screen.dart';
import 'screens/service_selection_screen.dart';
import 'screens/governmental_services_screen.dart';
import 'package:provider/provider.dart';
import 'theme/theme_provider.dart';
import 'screens/commercial_services_screen.dart';
import 'screens/events_screen.dart';
import 'screens/events_reservation_screen.dart';
import 'screens/events_inquiry_screen.dart';
import 'screens/entertainment_screen.dart';
import 'screens/diving_activities_screen.dart';
import 'screens/snorkeling_activities_screen.dart';
import 'screens/safari_activities_screen.dart';
import 'screens/nightlife_activities_screen.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform, // Pass Firebase options
    
  );

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Locale _locale = const Locale('en');

  void _setLocale(Locale locale) {
    setState(() {
      _locale = locale;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'Sharm Super App',
          locale: _locale,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          supportedLocales: const [
            Locale('en'),
            Locale('ar'),
          ],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          // Disable swipe back gesture globally
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                navigationMode: NavigationMode.traditional,
              ),
              child: WillPopScope(
                onWillPop: () async => false,
                child: child!,
              ),
            );
          },
          routes: {
            '/': (context) => SplashScreen(setLocale: _setLocale),
            '/welcome': (context) => WelcomeScreen(setLocale: _setLocale),
            '/login': (context) => LoginScreen(onLanguageChange: _setLocale),
            '/services_home_page': (context) => ServicesHomePage(
              username: FirebaseAuth.instance.currentUser?.email ?? 'User',
              setLocale: _setLocale,
            ),
            '/merchant_home_page': (context) => MerchantHomePage(
              username: FirebaseAuth.instance.currentUser?.email ?? 'User',
              setLocale: _setLocale,
            ),
            '/merchant_add': (context) => const ServiceAddScreen(),
            '/merchant_items': (context) => const MerchantItemsScreen(),
            '/register': (context) => RegisterScreen(),
            '/merchant_edit': (context) => const MerchantEditScreen(),
            '/item_details': (context) => const ItemDetailsScreen(),
            '/browse': (context) => const BrowseScreen(),
            '/favorites': (context) => const FavoritesScreen(),
            '/chat': (context) => const ChatScreen(),
            '/cart': (context) => const CartScreen(),
            '/profile': (context) => ProfileScreen(
              setLocale: _setLocale,
            ),
            '/orders': (context) => const OrdersScreen(),
            '/merchant_orders': (context) => const MerchantOrdersScreen(),
            '/visa': (context) => const VisaScreen(),
            '/visa_request': (context) => const VisaRequestScreen(),
            '/visa_inquiry': (context) => const VisaInquiryScreen(),
            '/museums': (context) => const MuseumsScreen(),
            '/museums_reservation': (context) => const MuseumsReservationScreen(),
            '/museums_inquiry': (context) => const MuseumsInquiryScreen(),
            '/services': (context) => const ServicesSelectionScreen(),
            '/governmental-services': (context) => const GovernmentalServicesScreen(),
            '/commercial-services': (context) => const CommercialServicesScreen(),
            '/events': (context) => const EventsScreen(),
            '/events_reservation': (context) => const EventsReservationScreen(),
            '/events_inquiry': (context) => const EventsInquiryScreen(),
            '/entertainment': (context) => const EntertainmentScreen(),
            '/diving': (context) => const DivingActivitiesScreen(),
            '/diving-detail': (context) {
              final activity = ModalRoute.of(context)!.settings.arguments as DivingActivity;
              return DivingActivitiesScreen(activity: activity);
            },
            '/snorkeling': (context) => const SnorkelingActivitiesScreen(),
            '/safari': (context) => const SafariActivitiesScreen(),
            '/nightlife': (context) => const NightlifeActivitiesScreen(),
          },
        );
      },
    );
  }
}
// Custom PageTransitionsBuilder
class NoSlidingPageTransitionsBuilder extends PageTransitionsBuilder {
  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeTransition(
      opacity: animation,
      child: child,
    );
  }
}

