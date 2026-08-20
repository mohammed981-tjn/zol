// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class LEn extends L {
  LEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'zol';

  @override
  String get navHome => 'Home';

  @override
  String get navMarket => 'Market';

  @override
  String get navTemplates => 'Templates';

  @override
  String get navMyAds => 'My ads';

  @override
  String get navOrders => 'Orders';

  @override
  String get navSettings => 'Settings';

  @override
  String get homeTagline => 'The complete advertising marketplace';

  @override
  String get homeSubtitle =>
      'From an idea to a printed, delivered ad in minutes';

  @override
  String get homeCta => 'Create your ad now';

  @override
  String get homeCtaHint => 'Live preview in under 90 seconds';

  @override
  String get homeStatAds => 'saved ads';

  @override
  String get homeStatOrders => 'print orders';

  @override
  String homeWelcome(String name) {
    return 'Welcome, $name 👋';
  }

  @override
  String get templatesSearchHint => 'Search templates — story, banner, card…';

  @override
  String get templatesEmpty => 'No templates match your search';

  @override
  String get templatesKicker => 'Start from a template';

  @override
  String get templatesTitle => 'Pick the shape you want';

  @override
  String get templatesSampleProduct => 'Your product name';

  @override
  String get templatesSampleTone => 'Energetic';

  @override
  String get templatesPrintable => 'Printable';

  @override
  String get templatesTrending => '🔥 Trending';

  @override
  String get myAdsTrash => 'Trash';

  @override
  String get myAdsEmptyTitle => 'Your library is empty';

  @override
  String get myAdsEmptyBody =>
      'Save the versions you like from the Magic screen and find them here, ready to reuse or print.';

  @override
  String get myAdsKicker => 'Library';

  @override
  String get myAdsTitle => 'Your saved ads';

  @override
  String get myAdsOpenHint =>
      'Tap to open the design and export or print it again';

  @override
  String get myAdsCopyText => 'Copy text';

  @override
  String get myAdsDelete => 'Delete';

  @override
  String get myAdsCopied => 'Ad text copied';

  @override
  String get myAdsMovedToTrash => 'Ad moved to trash';

  @override
  String get actionUndo => 'Undo';

  @override
  String get ordersEmptyTitle => 'No orders yet';

  @override
  String get ordersEmptyBody =>
      'Choose “Print and deliver” after generating your ad and the order will appear here with a timeline you can follow.';

  @override
  String get ordersKicker => 'Tracking';

  @override
  String get ordersTitle => 'Print order status';

  @override
  String ordersDeliverTo(String address) {
    return 'Deliver to: $address';
  }

  @override
  String ordersShop(String shop) {
    return 'Print shop: $shop';
  }

  @override
  String get ordersPaidByCard => 'Paid by card ✓';

  @override
  String get ordersCashOnDelivery => 'Cash on delivery';

  @override
  String get ordersShowOnMap => 'Show on map';

  @override
  String get ordersSimulate => 'Simulate progress (demo)';

  @override
  String get trashTitle => 'Trash';

  @override
  String get trashEmptyAction => 'Empty trash';

  @override
  String get trashEmptyTitle => 'Trash is empty';

  @override
  String trashEmptyBody(int days) {
    return 'Ads you delete from “My ads” stay here for $days days before they are removed for good,\nand you can restore them any time before that.';
  }

  @override
  String get trashKicker => 'Restore or delete for good';

  @override
  String trashCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ads in trash',
      one: 'One ad in trash',
    );
    return '$_temp0';
  }

  @override
  String get trashConfirmTitle => 'Empty the trash for good?';

  @override
  String trashConfirmBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ads will be deleted for good. This cannot be undone.',
      one: 'One ad will be deleted for good. This cannot be undone.',
    );
    return '$_temp0';
  }

  @override
  String get actionCancel => 'Cancel';

  @override
  String get trashConfirmAction => 'Delete for good';

  @override
  String get trashExpiringSoon => 'Will be deleted for good soon';

  @override
  String trashExpiresIn(int days) {
    return 'Deleted for good in $days days';
  }

  @override
  String get trashRestore => 'Restore';

  @override
  String get trashDeleteForever => 'Delete for good';

  @override
  String get marketTitle => 'Market';

  @override
  String get marketSearchHint => 'Find a photographer, print shop, designer…';

  @override
  String get marketClearSearch => 'Clear search';

  @override
  String get marketAll => 'All';

  @override
  String get marketAllCities => 'All cities';

  @override
  String get marketEmptyTitle => 'No provider matches your search';

  @override
  String get marketEmptyBody => 'Try another city or clear the filters';

  @override
  String get marketClearFilters => 'Clear filters';

  @override
  String get marketVerified => 'Verified';

  @override
  String marketPriceFrom(int price) {
    return 'From SAR $price';
  }

  @override
  String get marketOnRequest => 'On request';

  @override
  String marketRespondsIn(int hours) {
    return 'Replies within $hours hours';
  }

  @override
  String marketRatingSemantics(String rating, int reviews) {
    return 'Rated $rating out of 5, $reviews reviews';
  }

  @override
  String marketReviewsCount(int reviews) {
    return '($reviews reviews)';
  }

  @override
  String get storefrontMine => 'My storefront';

  @override
  String storefrontNamed(String store) {
    return '$store storefront';
  }

  @override
  String get storefrontEmptyHint =>
      'Show your identity and your work — start by saving an ad';

  @override
  String storefrontAdsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ads',
      one: 'one ad',
    );
    return 'Your storefront: $_temp0';
  }

  @override
  String get storefrontShare => 'Share your storefront';

  @override
  String get storefrontEmptyTitle =>
      'Your storefront is ready and waiting for its first piece';

  @override
  String get storefrontEmptyBody =>
      'Every ad you save from the Magic screen appears here on display.';

  @override
  String storefrontShowcase(int count) {
    return 'On display ($count)';
  }

  @override
  String get storefrontShareEmpty =>
      'Save an ad first so your storefront is worth sharing';

  @override
  String storefrontSharePending(String store) {
    return 'The public link for $store is being prepared';
  }

  @override
  String storefrontHarmony(String scheme) {
    return 'Harmony: $scheme';
  }

  @override
  String get storefrontBrandColor => 'Brand colour';

  @override
  String get storefrontSupportColor => 'Supporting colour';

  @override
  String get providerPrice => 'Price';

  @override
  String get providerResponseTime => 'Response time';

  @override
  String providerResponseHours(int hours) {
    return '~$hours hours';
  }

  @override
  String get providerStatus => 'Status';

  @override
  String get providerWorks => 'Past work';

  @override
  String get providerRequestQuote => 'Request a quote';

  @override
  String get providerDisclaimer =>
      'Your request reaches registered providers directly. Print-network providers receive it through the “Send it yourself” button.';

  @override
  String providerReviewsCount(int reviews) {
    return '($reviews reviews)';
  }

  @override
  String printPricesNote(String delivery, int vat) {
    return 'Prices are per unit, before delivery ($delivery) and $vat% VAT.';
  }

  @override
  String get printOrder => 'Order';

  @override
  String get printNeedsDesign =>
      'Design and save an ad first — printing needs a design';

  @override
  String get printWhichDesign => 'Which design are you printing?';

  @override
  String get marketNewProvider => 'New — no reviews yet';

  @override
  String get providerSignupTitle => 'List your service in the market';

  @override
  String get providerSignupIntro =>
      'Put your service in front of zol merchants. Listing is free, and review is done by a human within a day or two — your listing does not appear before that.';

  @override
  String get providerSignupKind => 'Service type';

  @override
  String get providerSignupName => 'Business name';

  @override
  String get providerSignupNameError =>
      'Enter a name of at least two characters';

  @override
  String get providerSignupCity => 'City';

  @override
  String get providerSignupCityError => 'Enter your city';

  @override
  String get providerSignupTagline => 'What do you offer?';

  @override
  String get providerSignupTaglineHelp =>
      'One line saying what you are good at — not a marketing slogan';

  @override
  String get providerSignupTaglineError =>
      'Write at least ten characters so merchants understand your service';

  @override
  String get providerSignupPrice => 'Lowest price in SAR (optional)';

  @override
  String get providerSignupPriceHelp =>
      'Leave it empty if your service is priced on request';

  @override
  String get providerSignupPriceError => 'Enter a valid number';

  @override
  String get providerSignupHours => 'Response time in hours (optional)';

  @override
  String get providerSignupHoursHelp =>
      'How long you usually take to answer a request';

  @override
  String get providerSignupHoursError =>
      'Enter a number of hours between 1 and 720';

  @override
  String get providerSignupWorks => 'Past work (optional)';

  @override
  String get providerSignupWorksHelp => 'One title per line — up to twelve';

  @override
  String get providerSignupSubmit => 'Send for review';

  @override
  String get providerSignupReviewNote =>
      'The gold verified badge is granted after we review your commercial registration; it is not requested here.';

  @override
  String get providerSignupSent =>
      'Your request arrived — we will review it and let you know';

  @override
  String get providerSignupDuplicate =>
      'You already have a listing for this service type';

  @override
  String get providerSignupFailed =>
      'Could not send — check your connection and try again';

  @override
  String get providerSignupNeedsAccount =>
      'Sign in first to list your service in the market';

  @override
  String get providerSignupOneListing =>
      'One listing per service type. To edit your details or add another type, contact us from Settings.';

  @override
  String get marketJoin => 'List your service';

  @override
  String get wishHint =>
      'Write what you want… e.g. a roll-up with 30% off, elegant';

  @override
  String get wishRun => 'Run';

  @override
  String get wishFailed => 'Could not carry out your request. Try again.';

  @override
  String get roleHeadline => 'Headline';

  @override
  String get roleSubhead => 'Subhead';

  @override
  String get roleProduct => 'Product';

  @override
  String get roleCta => 'Call to action';

  @override
  String get roleBadge => 'Badge';

  @override
  String get roleLogo => 'Logo';

  @override
  String get roleTags => 'Hashtags';

  @override
  String get roleShape => 'Shape';

  @override
  String get editorTitle => 'Edit design';

  @override
  String get editorResizeHandle => 'Resize handle';

  @override
  String get editorSpecHint =>
      'Tap an element to select it, then drag to move it or drag the handle to resize';

  @override
  String get editorProductHint => 'Drag to move the product, pinch to zoom';

  @override
  String get editorNoProductHint => 'Add a product photo to be able to move it';

  @override
  String get editorResetProduct => 'Reset the product position';

  @override
  String get editorResetLayout => 'Reset the layout as generated';

  @override
  String get editorEditText => 'Edit text';

  @override
  String get editorEditElement => 'Edit selected element';

  @override
  String get editorElementText => 'Element text';

  @override
  String get editorFieldHeadline => 'Headline';

  @override
  String get editorFieldBody => 'Subhead';

  @override
  String get editorFieldCta => 'Call-to-action button';

  @override
  String get editorApply => 'Apply';

  @override
  String get editorSaveChanges => 'Save changes';

  @override
  String get editorDone => 'Done';

  @override
  String get executeEditTemplate => 'Edit design (text and product position)';

  @override
  String get executeEditSpec =>
      'Edit design (move elements and change their text)';

  @override
  String get executeGeneratedNote =>
      'This layout was composed by AI for your request, so template choice does not apply to it. Move it as you like, or ask the Magic screen for another layout.';

  @override
  String get wishRefineChip => 'Edit this design';

  @override
  String get wishRefineHint =>
      'Write what to change… e.g. make the headline bigger and the background light';

  @override
  String get wishPresetDiscount => '50% off this weekend';

  @override
  String get wishPresetOpening => 'New branch opening';

  @override
  String get wishPresetNewItem => 'New item just arrived';

  @override
  String get wishPresetHiring => 'We are hiring';

  @override
  String get wishPresetDelivery => 'Free delivery today';

  @override
  String get wishPresetRamadan => 'Ramadan offer';

  @override
  String get quoteSheetTitle => 'Request a quote';

  @override
  String get quoteNeedLabel => 'What do you need?';

  @override
  String get quoteNeedHelp =>
      'Be specific: quantity, size, and a deadline if you have one';

  @override
  String get quoteNeedError =>
      'Write at least ten characters so the provider understands';

  @override
  String get quoteBudgetLabel => 'Approximate budget in SAR (optional)';

  @override
  String get quoteContactLabel => 'How should they reply?';

  @override
  String get quoteContactHelp =>
      'A WhatsApp number or an email — without one no quote reaches you';

  @override
  String get quoteContactError => 'Enter a valid number or email';

  @override
  String get quoteSend => 'Send request';

  @override
  String get quoteShare => 'Send it yourself';

  @override
  String get quoteDelivered => 'Your request reached the provider';

  @override
  String get quoteOffline =>
      'Could not send through the app — send it yourself with the button below';

  @override
  String get quoteNeedsAccount =>
      'Sign in first so the request is attributed to you and the reply reaches you';

  @override
  String get quoteNotRoutable =>
      'This provider is from the print network and does not receive through the app — copy the request and send it to them';

  @override
  String get quoteCopied => 'Request text copied';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLanguageSystem => 'Device language';

  @override
  String get settingsLanguageArabic => 'العربية';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsLanguageNote =>
      'Changing the language changes the app interface only. Your ad copy stays in your audience\'s language.';

  @override
  String get onboardingSkip => 'Skip';

  @override
  String get onboardingNext => 'Next';

  @override
  String get onboardingStart => 'Get started';

  @override
  String get onboardingPickFirst => 'Pick your business to continue';

  @override
  String get onboardingT1 => 'Your ad is born in seconds';

  @override
  String get onboardingB1 =>
      'Upload a photo of your product, pick a tone and a platform, and we hand you copy and a design ready to post.';

  @override
  String get onboardingT2 => 'Print it at the nearest shop';

  @override
  String get onboardingB2 =>
      'Banners, stickers, cards and roll-ups with instant pricing — and your order goes to the partner print shop nearest you.';

  @override
  String get onboardingT3 => 'And it arrives at your door';

  @override
  String get onboardingB3 =>
      'Drop your location on the map and follow the order step by step until it is in your hands.';

  @override
  String get onboardingCategoryTitle => 'What is your business?';

  @override
  String get onboardingCategoryBody =>
      'We write copy in the vocabulary of your field — not generic lines that fit anything.';

  @override
  String get onboardingCategoryHint => 'You can change this later in Settings';

  @override
  String get authEmailError => 'Enter a valid email address';

  @override
  String get authPasswordError => 'Password must be at least 6 characters';

  @override
  String get authNameError => 'Enter your name';

  @override
  String get authStoreError => 'Enter your store or business name';

  @override
  String get authTitleLogin => 'Sign in';

  @override
  String get authTitleSignup => 'Create a merchant account';

  @override
  String get authIntroLogin => 'Sign in to pick up your ads and orders';

  @override
  String get authIntroSignup =>
      'Create a merchant account to save your ads and track your orders';

  @override
  String get authFieldName => 'Name *';

  @override
  String get authHintName => 'Your full name';

  @override
  String get authFieldStore => 'Store name *';

  @override
  String get authHintStore => 'e.g. Al-Fajr Roastery';

  @override
  String get authFieldEmail => 'Email *';

  @override
  String get authFieldPassword => 'Password *';

  @override
  String get authHintPassword => 'At least 6 characters';

  @override
  String get authSubmitLogin => 'Sign in';

  @override
  String get authSubmitSignup => 'Create account';

  @override
  String get authSwitchToSignup => 'No account yet? Create one';

  @override
  String get authSwitchToLogin => 'Already have an account? Sign in';

  @override
  String authWelcomeBack(String name) {
    return 'Welcome back, $name!';
  }

  @override
  String authAccountCreated(String name) {
    return 'Your account is ready, $name!';
  }

  @override
  String get wishLocalOnly =>
      'Designed on your device — the cloud AI was unreachable';

  @override
  String get magicTitle => 'Magic screen';

  @override
  String get magicRegenerate => 'Regenerate';

  @override
  String get magicFailed => 'Generation could not finish. Try again.';

  @override
  String get magicSceneFailed => 'The scene could not be generated. Try again.';

  @override
  String get magicQuotaTitle => 'You have used this month\'s quota';

  @override
  String get magicErrorTitle => 'Generation failed';

  @override
  String get magicRetry => 'Try again';

  @override
  String get magicBackAndEdit => 'Go back and edit the description';

  @override
  String get magicWorking => 'AI is working on your ad…';

  @override
  String get magicStepKicker => 'Step 2 of 3';

  @override
  String get magicPickBest => 'Pick the version that fits';

  @override
  String get magicSaveAndPublish => 'Save and publish';

  @override
  String get magicPrintAndDeliver => 'Print and deliver';

  @override
  String get magicSavedToLibrary => 'Saved to “My ads”';

  @override
  String get magicCopied => 'Ad text copied';

  @override
  String get magicRealScene => 'Realistic AI scene';

  @override
  String get magicCopyText => 'Copy text';

  @override
  String get magicSave => 'Save';

  @override
  String magicMatchScore(int score) {
    return '$score% match';
  }
}
