import 'package:banay/localization/banay_localization_auth_keys.dart';

const Map<String, Map<String, String>> banayAuthLocalizedValues = {
  'mg': {
    BanayAuthLocalizationKeys.languagePageTitle: 'Akory, tonga soa ato @ BANAY',
    BanayAuthLocalizationKeys.languagePageSubtitle:
        'Safidio ny fiteninao hanombohana',
    BanayAuthLocalizationKeys.phonePageTitle: 'Tongasoa eto @ BANAY',
    BanayAuthLocalizationKeys.phonePageSubtitleLine1:
        'Mila manamarina ny laharan-telefaoninao i BANAY',
    BanayAuthLocalizationKeys.phonePageSubtitleLine2:
        'mba hidiranao ao amin\'ny kaontinao',
    BanayAuthLocalizationKeys.country: 'Firenena',
    BanayAuthLocalizationKeys.chooseCountryTooltip: 'Misafidiana firenena',
    BanayAuthLocalizationKeys.phoneNumber: 'Laharana finday',
    BanayAuthLocalizationKeys.simDetectionInProgress: 'Mitady...',
    BanayAuthLocalizationKeys.useSimNumber: 'Ampiasao ny nomerao SIM-ko',
    BanayAuthLocalizationKeys.detectedNumber: 'Nomerao hita: {number}',
    BanayAuthLocalizationKeys.sendingOtp: 'Mandefa OTP...',
    BanayAuthLocalizationKeys.simNumberUnavailable:
        'Tsy afaka mamantatra ho azy ny laharan\'ny SIM ity finday ity. Azonao soratana tanana ny laharana.',
    BanayAuthLocalizationKeys.simNumberDetected:
        'Nomeraon\'ny SIM hita: {number}',
    BanayAuthLocalizationKeys.invalidPhoneNumber:
        'Misafidiana firenena ary ampidiro laharana marina.',
    BanayAuthLocalizationKeys.confirmNumber: 'Hamarino ny laharana',
    BanayAuthLocalizationKeys.otpSmsSent:
        'Hisy kaody OTP halefa amin\'ity laharana ity amin\'ny SMS.',
    BanayAuthLocalizationKeys.verifyNumberTitle: 'Hamarino ny laharanao',
    BanayAuthLocalizationKeys.enterCodeMessage:
        'Ampidiro ny kaody 6 isa nalefa tany amin\'ny {phone}. Raha tohanan\'ny fitaovana dia ho hita ho azy ilay kaody.',
    BanayAuthLocalizationKeys.autodetectUnavailable:
        'Tsy misy auto-detection amin\'ity fitaovana ity, fa mbola mandeha ny fampidirana OTP tanana.',
    BanayAuthLocalizationKeys.devModeCurrentOtp:
        'Mode dev: OTP ankehitriny {code}',
    BanayAuthLocalizationKeys.resendAvailableIn:
        'Afaka mangataka fandefasana indray afaka {seconds}s',
    BanayAuthLocalizationKeys.requestNewOtpNow:
        'Afaka mangataka OTP vaovao izao ianao.',
    BanayAuthLocalizationKeys.verifying: 'Manamarina...',
    BanayAuthLocalizationKeys.verifyOtp: 'Hamarino OTP',
    BanayAuthLocalizationKeys.resending: 'Mandefa indray...',
    BanayAuthLocalizationKeys.resendCode: 'Alefa indray ny kaody',
    BanayAuthLocalizationKeys.otpAutoDetectionTitle: 'Fikarohana ho azy ny OTP',
    BanayAuthLocalizationKeys.otpVerifyingInProgress:
        'Eo am-panamarinana ny kaody. Andraso azafady.',
    BanayAuthLocalizationKeys.newOtpSent: 'Nalefa indray ny kaody OTP vaovao.',
    BanayAuthLocalizationKeys.addValidName: 'Ampidiro anarana mety hanohizana.',
    BanayAuthLocalizationKeys.almostThere: 'Efa ho vita!',
    BanayAuthLocalizationKeys.addNamePicture:
        'Ampio ny anaranao sy sary profil',
    BanayAuthLocalizationKeys.yourName: 'Ny anaranao',
    BanayAuthLocalizationKeys.connecting: 'Mampifandray...',
  },
  'en': {
    BanayAuthLocalizationKeys.languagePageTitle: 'Hello, welcome to BANAY',
    BanayAuthLocalizationKeys.languagePageSubtitle:
        'Choose your language to get started',
    BanayAuthLocalizationKeys.phonePageTitle: 'Welcome to BANAY',
    BanayAuthLocalizationKeys.phonePageSubtitleLine1:
        'BANAY needs to verify your phone number',
    BanayAuthLocalizationKeys.phonePageSubtitleLine2:
        'to connect to your account',
    BanayAuthLocalizationKeys.country: 'Country',
    BanayAuthLocalizationKeys.chooseCountryTooltip: 'Choose a country',
    BanayAuthLocalizationKeys.phoneNumber: 'Phone Number',
    BanayAuthLocalizationKeys.simDetectionInProgress: 'Detecting...',
    BanayAuthLocalizationKeys.useSimNumber: 'Use my SIM number',
    BanayAuthLocalizationKeys.detectedNumber: 'Detected number: {number}',
    BanayAuthLocalizationKeys.sendingOtp: 'Sending OTP...',
    BanayAuthLocalizationKeys.simNumberUnavailable:
        'This phone cannot automatically provide the SIM card number. You can enter the number manually.',
    BanayAuthLocalizationKeys.simNumberDetected:
        'SIM number detected: {number}',
    BanayAuthLocalizationKeys.invalidPhoneNumber:
        'Select a country and enter a valid phone number.',
    BanayAuthLocalizationKeys.confirmNumber: 'Confirm number',
    BanayAuthLocalizationKeys.otpSmsSent:
        'An OTP code will be sent by SMS to this number.',
    BanayAuthLocalizationKeys.verifyNumberTitle: 'Verify your number',
    BanayAuthLocalizationKeys.enterCodeMessage:
        'Enter the 6-digit code sent to {phone}. On compatible devices, the code will be detected automatically.',
    BanayAuthLocalizationKeys.autodetectUnavailable:
        'Auto-detection is unavailable on this device, but manual OTP entry still works.',
    BanayAuthLocalizationKeys.devModeCurrentOtp: 'Dev mode: current OTP {code}',
    BanayAuthLocalizationKeys.resendAvailableIn:
        'Resend available in {seconds}s',
    BanayAuthLocalizationKeys.requestNewOtpNow:
        'You can request a new OTP now.',
    BanayAuthLocalizationKeys.verifying: 'Verifying...',
    BanayAuthLocalizationKeys.verifyOtp: 'Verify OTP',
    BanayAuthLocalizationKeys.resending: 'Resending...',
    BanayAuthLocalizationKeys.resendCode: 'Resend code',
    BanayAuthLocalizationKeys.otpAutoDetectionTitle: 'Automatic OTP detection',
    BanayAuthLocalizationKeys.otpVerifyingInProgress:
        'Code verification in progress. Please wait.',
    BanayAuthLocalizationKeys.newOtpSent: 'A new OTP code has been sent.',
    BanayAuthLocalizationKeys.addValidName: 'Add a valid name to continue.',
    BanayAuthLocalizationKeys.almostThere: 'Almost there!',
    BanayAuthLocalizationKeys.addNamePicture:
        'Add your name and a profile picture',
    BanayAuthLocalizationKeys.yourName: 'Your Name',
    BanayAuthLocalizationKeys.connecting: 'Connecting...',
  },
  'fr': {
    BanayAuthLocalizationKeys.languagePageTitle: 'Bonjour, bienvenue sur BANAY',
    BanayAuthLocalizationKeys.languagePageSubtitle:
        'Choisissez votre langue pour commencer',
    BanayAuthLocalizationKeys.phonePageTitle: 'Bienvenue sur BANAY',
    BanayAuthLocalizationKeys.phonePageSubtitleLine1:
        'BANAY doit verifier votre numero de telephone',
    BanayAuthLocalizationKeys.phonePageSubtitleLine2:
        'pour vous connecter a votre compte',
    BanayAuthLocalizationKeys.country: 'Pays',
    BanayAuthLocalizationKeys.chooseCountryTooltip: 'Choisir un pays',
    BanayAuthLocalizationKeys.phoneNumber: 'Numero de telephone',
    BanayAuthLocalizationKeys.simDetectionInProgress: 'Detection...',
    BanayAuthLocalizationKeys.useSimNumber: 'Utiliser mon numero SIM',
    BanayAuthLocalizationKeys.detectedNumber: 'Numero detecte : {number}',
    BanayAuthLocalizationKeys.sendingOtp: 'Envoi OTP...',
    BanayAuthLocalizationKeys.simNumberUnavailable:
        'Ce telephone ne fournit pas automatiquement le numero de la carte SIM. Vous pouvez saisir le numero manuellement.',
    BanayAuthLocalizationKeys.simNumberDetected:
        'Numero SIM detecte : {number}',
    BanayAuthLocalizationKeys.invalidPhoneNumber:
        'Selectionnez un pays et saisissez un numero valide.',
    BanayAuthLocalizationKeys.confirmNumber: 'Confirmer le numero',
    BanayAuthLocalizationKeys.otpSmsSent:
        'Un code OTP sera envoye par SMS a ce numero.',
    BanayAuthLocalizationKeys.verifyNumberTitle: 'Verifiez votre numero',
    BanayAuthLocalizationKeys.enterCodeMessage:
        'Entrez le code a 6 chiffres envoye au {phone}. Sur les appareils compatibles, le code sera detecte automatiquement.',
    BanayAuthLocalizationKeys.autodetectUnavailable:
        'La detection automatique est indisponible sur cet appareil, mais la saisie manuelle de l\'OTP fonctionne toujours.',
    BanayAuthLocalizationKeys.devModeCurrentOtp: 'Mode dev : OTP actuel {code}',
    BanayAuthLocalizationKeys.resendAvailableIn:
        'Nouvel envoi disponible dans {seconds}s',
    BanayAuthLocalizationKeys.requestNewOtpNow:
        'Vous pouvez demander un nouvel OTP maintenant.',
    BanayAuthLocalizationKeys.verifying: 'Verification...',
    BanayAuthLocalizationKeys.verifyOtp: 'Verifier OTP',
    BanayAuthLocalizationKeys.resending: 'Renvoi...',
    BanayAuthLocalizationKeys.resendCode: 'Renvoyer le code',
    BanayAuthLocalizationKeys.otpAutoDetectionTitle:
        'Detection automatique de l\'OTP',
    BanayAuthLocalizationKeys.otpVerifyingInProgress:
        'Verification du code en cours. Veuillez patienter.',
    BanayAuthLocalizationKeys.newOtpSent: 'Un nouveau code OTP a ete envoye.',
    BanayAuthLocalizationKeys.addValidName:
        'Ajoutez un nom valide pour continuer.',
    BanayAuthLocalizationKeys.almostThere: 'Presque fini !',
    BanayAuthLocalizationKeys.addNamePicture:
        'Ajoutez votre nom et une photo de profil',
    BanayAuthLocalizationKeys.yourName: 'Votre nom',
    BanayAuthLocalizationKeys.connecting: 'Connexion...',
  },
  'zh': {
    BanayAuthLocalizationKeys.languagePageTitle: '你好，欢迎来到 BANAY',
    BanayAuthLocalizationKeys.languagePageSubtitle: '选择你的语言以开始',
    BanayAuthLocalizationKeys.phonePageTitle: '欢迎来到 BANAY',
    BanayAuthLocalizationKeys.phonePageSubtitleLine1: 'BANAY 需要验证你的电话号码',
    BanayAuthLocalizationKeys.phonePageSubtitleLine2: '以便登录你的账户',
    BanayAuthLocalizationKeys.country: '国家',
    BanayAuthLocalizationKeys.chooseCountryTooltip: '选择国家',
    BanayAuthLocalizationKeys.phoneNumber: '电话号码',
    BanayAuthLocalizationKeys.simDetectionInProgress: '检测中...',
    BanayAuthLocalizationKeys.useSimNumber: '使用我的 SIM 号码',
    BanayAuthLocalizationKeys.detectedNumber: '检测到的号码：{number}',
    BanayAuthLocalizationKeys.sendingOtp: '正在发送 OTP...',
    BanayAuthLocalizationKeys.simNumberUnavailable:
        '此设备无法自动提供 SIM 卡号码。你可以手动输入号码。',
    BanayAuthLocalizationKeys.simNumberDetected: '检测到 SIM 号码：{number}',
    BanayAuthLocalizationKeys.invalidPhoneNumber: '请选择国家并输入有效号码。',
    BanayAuthLocalizationKeys.confirmNumber: '确认号码',
    BanayAuthLocalizationKeys.otpSmsSent: 'OTP 验证码将通过短信发送到此号码。',
    BanayAuthLocalizationKeys.verifyNumberTitle: '验证你的号码',
    BanayAuthLocalizationKeys.enterCodeMessage:
        '请输入发送到 {phone} 的 6 位代码。在兼容设备上，代码会自动检测。',
    BanayAuthLocalizationKeys.autodetectUnavailable: '此设备不支持自动检测，但仍可手动输入 OTP。',
    BanayAuthLocalizationKeys.devModeCurrentOtp: '开发模式：当前 OTP {code}',
    BanayAuthLocalizationKeys.resendAvailableIn: '{seconds} 秒后可重新发送',
    BanayAuthLocalizationKeys.requestNewOtpNow: '你现在可以请求新的 OTP。',
    BanayAuthLocalizationKeys.verifying: '验证中...',
    BanayAuthLocalizationKeys.verifyOtp: '验证 OTP',
    BanayAuthLocalizationKeys.resending: '重新发送中...',
    BanayAuthLocalizationKeys.resendCode: '重新发送代码',
    BanayAuthLocalizationKeys.otpAutoDetectionTitle: '自动检测 OTP',
    BanayAuthLocalizationKeys.otpVerifyingInProgress: '正在验证代码。请稍候。',
    BanayAuthLocalizationKeys.newOtpSent: '新的 OTP 代码已发送。',
    BanayAuthLocalizationKeys.addValidName: '请输入有效姓名以继续。',
    BanayAuthLocalizationKeys.almostThere: '快完成了！',
    BanayAuthLocalizationKeys.addNamePicture: '添加你的姓名和头像',
    BanayAuthLocalizationKeys.yourName: '你的姓名',
    BanayAuthLocalizationKeys.connecting: '连接中...',
  },
  'hi': {
    BanayAuthLocalizationKeys.languagePageTitle:
        'नमस्ते, BANAY में आपका स्वागत है',
    BanayAuthLocalizationKeys.languagePageSubtitle:
        'शुरू करने के लिए अपनी भाषा चुनें',
    BanayAuthLocalizationKeys.phonePageTitle: 'BANAY में आपका स्वागत है',
    BanayAuthLocalizationKeys.phonePageSubtitleLine1:
        'BANAY को आपका फोन नंबर सत्यापित करना है',
    BanayAuthLocalizationKeys.phonePageSubtitleLine2:
        'ताकि आप अपने खाते में लॉग इन कर सकें',
    BanayAuthLocalizationKeys.country: 'देश',
    BanayAuthLocalizationKeys.chooseCountryTooltip: 'देश चुनें',
    BanayAuthLocalizationKeys.phoneNumber: 'फोन नंबर',
    BanayAuthLocalizationKeys.simDetectionInProgress: 'पता लगाया जा रहा है...',
    BanayAuthLocalizationKeys.useSimNumber: 'मेरा SIM नंबर उपयोग करें',
    BanayAuthLocalizationKeys.detectedNumber: 'मिला नंबर: {number}',
    BanayAuthLocalizationKeys.sendingOtp: 'OTP भेजा जा रहा है...',
    BanayAuthLocalizationKeys.simNumberUnavailable:
        'यह फोन SIM नंबर अपने आप उपलब्ध नहीं कराता। आप नंबर मैन्युअल रूप से दर्ज कर सकते हैं।',
    BanayAuthLocalizationKeys.simNumberDetected: 'SIM नंबर मिला: {number}',
    BanayAuthLocalizationKeys.invalidPhoneNumber:
        'कृपया देश चुनें और एक मान्य नंबर दर्ज करें।',
    BanayAuthLocalizationKeys.confirmNumber: 'नंबर की पुष्टि करें',
    BanayAuthLocalizationKeys.otpSmsSent:
        'इस नंबर पर SMS द्वारा OTP कोड भेजा जाएगा।',
    BanayAuthLocalizationKeys.verifyNumberTitle: 'अपना नंबर सत्यापित करें',
    BanayAuthLocalizationKeys.enterCodeMessage:
        '{phone} पर भेजा गया 6 अंकों का कोड दर्ज करें। समर्थित डिवाइस पर कोड अपने आप मिल जाएगा।',
    BanayAuthLocalizationKeys.autodetectUnavailable:
        'इस डिवाइस पर ऑटो-डिटेक्शन उपलब्ध नहीं है, लेकिन मैन्युअल OTP अभी भी काम करता है।',
    BanayAuthLocalizationKeys.devModeCurrentOtp: 'डेव मोड: वर्तमान OTP {code}',
    BanayAuthLocalizationKeys.resendAvailableIn:
        '{seconds}s में दोबारा भेजना उपलब्ध',
    BanayAuthLocalizationKeys.requestNewOtpNow: 'आप अभी नया OTP मांग सकते हैं।',
    BanayAuthLocalizationKeys.verifying: 'सत्यापित किया जा रहा है...',
    BanayAuthLocalizationKeys.verifyOtp: 'OTP सत्यापित करें',
    BanayAuthLocalizationKeys.resending: 'फिर से भेजा जा रहा है...',
    BanayAuthLocalizationKeys.resendCode: 'कोड फिर भेजें',
    BanayAuthLocalizationKeys.otpAutoDetectionTitle: 'स्वचालित OTP पहचान',
    BanayAuthLocalizationKeys.otpVerifyingInProgress:
        'कोड सत्यापन जारी है। कृपया प्रतीक्षा करें।',
    BanayAuthLocalizationKeys.newOtpSent: 'नया OTP कोड भेज दिया गया है।',
    BanayAuthLocalizationKeys.addValidName:
        'जारी रखने के लिए एक मान्य नाम दर्ज करें।',
    BanayAuthLocalizationKeys.almostThere: 'बस हो गया!',
    BanayAuthLocalizationKeys.addNamePicture:
        'अपना नाम और प्रोफ़ाइल photo जोड़ें',
    BanayAuthLocalizationKeys.yourName: 'आपका नाम',
    BanayAuthLocalizationKeys.connecting: 'कनेक्ट हो रहा है...',
  },
  'es': {
    BanayAuthLocalizationKeys.languagePageTitle: 'Hola, bienvenido a BANAY',
    BanayAuthLocalizationKeys.languagePageSubtitle:
        'Elige tu idioma para comenzar',
    BanayAuthLocalizationKeys.phonePageTitle: 'Bienvenido a BANAY',
    BanayAuthLocalizationKeys.phonePageSubtitleLine1:
        'BANAY necesita verificar tu numero de telefono',
    BanayAuthLocalizationKeys.phonePageSubtitleLine2:
        'para conectarte a tu cuenta',
    BanayAuthLocalizationKeys.country: 'Pais',
    BanayAuthLocalizationKeys.chooseCountryTooltip: 'Elegir un pais',
    BanayAuthLocalizationKeys.phoneNumber: 'Numero de telefono',
    BanayAuthLocalizationKeys.simDetectionInProgress: 'Detectando...',
    BanayAuthLocalizationKeys.useSimNumber: 'Usar mi numero SIM',
    BanayAuthLocalizationKeys.detectedNumber: 'Numero detectado: {number}',
    BanayAuthLocalizationKeys.sendingOtp: 'Enviando OTP...',
    BanayAuthLocalizationKeys.simNumberUnavailable:
        'Este telefono no proporciona automaticamente el numero de la tarjeta SIM. Puedes ingresarlo manualmente.',
    BanayAuthLocalizationKeys.simNumberDetected:
        'Numero SIM detectado: {number}',
    BanayAuthLocalizationKeys.invalidPhoneNumber:
        'Selecciona un pais e ingresa un numero valido.',
    BanayAuthLocalizationKeys.confirmNumber: 'Confirmar numero',
    BanayAuthLocalizationKeys.otpSmsSent:
        'Se enviara un codigo OTP por SMS a este numero.',
    BanayAuthLocalizationKeys.verifyNumberTitle: 'Verifica tu numero',
    BanayAuthLocalizationKeys.enterCodeMessage:
        'Ingresa el codigo de 6 digitos enviado a {phone}. En dispositivos compatibles, el codigo se detectara automaticamente.',
    BanayAuthLocalizationKeys.autodetectUnavailable:
        'La deteccion automatica no esta disponible en este dispositivo, pero el ingreso manual del OTP sigue funcionando.',
    BanayAuthLocalizationKeys.devModeCurrentOtp: 'Modo dev: OTP actual {code}',
    BanayAuthLocalizationKeys.resendAvailableIn:
        'Reenvio disponible en {seconds}s',
    BanayAuthLocalizationKeys.requestNewOtpNow:
        'Ahora puedes solicitar un nuevo OTP.',
    BanayAuthLocalizationKeys.verifying: 'Verificando...',
    BanayAuthLocalizationKeys.verifyOtp: 'Verificar OTP',
    BanayAuthLocalizationKeys.resending: 'Reenviando...',
    BanayAuthLocalizationKeys.resendCode: 'Reenviar codigo',
    BanayAuthLocalizationKeys.otpAutoDetectionTitle:
        'Deteccion automatica de OTP',
    BanayAuthLocalizationKeys.otpVerifyingInProgress:
        'Verificacion del codigo en curso. Espera por favor.',
    BanayAuthLocalizationKeys.newOtpSent: 'Se ha enviado un nuevo codigo OTP.',
    BanayAuthLocalizationKeys.addValidName:
        'Agrega un nombre valido para continuar.',
    BanayAuthLocalizationKeys.almostThere: 'Casi listo!',
    BanayAuthLocalizationKeys.addNamePicture:
        'Agrega tu nombre y una foto de perfil',
    BanayAuthLocalizationKeys.yourName: 'Tu nombre',
    BanayAuthLocalizationKeys.connecting: 'Conectando...',
  },
  'ar': {
    BanayAuthLocalizationKeys.languagePageTitle: 'مرحبا، أهلا بك في BANAY',
    BanayAuthLocalizationKeys.languagePageSubtitle: 'اختر لغتك للبدء',
    BanayAuthLocalizationKeys.phonePageTitle: 'أهلا بك في BANAY',
    BanayAuthLocalizationKeys.phonePageSubtitleLine1:
        'يحتاج BANAY إلى التحقق من رقم هاتفك',
    BanayAuthLocalizationKeys.phonePageSubtitleLine2: 'للدخول إلى حسابك',
    BanayAuthLocalizationKeys.country: 'البلد',
    BanayAuthLocalizationKeys.chooseCountryTooltip: 'اختر بلدا',
    BanayAuthLocalizationKeys.phoneNumber: 'رقم الهاتف',
    BanayAuthLocalizationKeys.simDetectionInProgress: 'جار الاكتشاف...',
    BanayAuthLocalizationKeys.useSimNumber: 'استخدم رقم SIM الخاص بي',
    BanayAuthLocalizationKeys.detectedNumber: 'الرقم المكتشف: {number}',
    BanayAuthLocalizationKeys.sendingOtp: 'جار إرسال OTP...',
    BanayAuthLocalizationKeys.simNumberUnavailable:
        'هذا الهاتف لا يوفر رقم بطاقة SIM تلقائيا. يمكنك إدخال الرقم يدويا.',
    BanayAuthLocalizationKeys.simNumberDetected: 'تم اكتشاف رقم SIM: {number}',
    BanayAuthLocalizationKeys.invalidPhoneNumber: 'اختر بلدا وأدخل رقما صالحا.',
    BanayAuthLocalizationKeys.confirmNumber: 'تأكيد الرقم',
    BanayAuthLocalizationKeys.otpSmsSent:
        'سيتم إرسال رمز OTP عبر SMS إلى هذا الرقم.',
    BanayAuthLocalizationKeys.verifyNumberTitle: 'تحقق من رقمك',
    BanayAuthLocalizationKeys.enterCodeMessage:
        'أدخل الرمز المكون من 6 أرقام المرسل إلى {phone}. على الأجهزة المتوافقة سيتم اكتشاف الرمز تلقائيا.',
    BanayAuthLocalizationKeys.autodetectUnavailable:
        'الكشف التلقائي غير متاح على هذا الجهاز، لكن إدخال OTP يدويا ما زال يعمل.',
    BanayAuthLocalizationKeys.devModeCurrentOtp:
        'وضع التطوير: OTP الحالي {code}',
    BanayAuthLocalizationKeys.resendAvailableIn:
        'إعادة الإرسال متاحة خلال {seconds}s',
    BanayAuthLocalizationKeys.requestNewOtpNow: 'يمكنك طلب OTP جديد الآن.',
    BanayAuthLocalizationKeys.verifying: 'جار التحقق...',
    BanayAuthLocalizationKeys.verifyOtp: 'تحقق من OTP',
    BanayAuthLocalizationKeys.resending: 'جار إعادة الإرسال...',
    BanayAuthLocalizationKeys.resendCode: 'إعادة إرسال الرمز',
    BanayAuthLocalizationKeys.otpAutoDetectionTitle: 'اكتشاف OTP تلقائيا',
    BanayAuthLocalizationKeys.otpVerifyingInProgress:
        'جار التحقق من الرمز. يرجى الانتظار.',
    BanayAuthLocalizationKeys.newOtpSent: 'تم إرسال رمز OTP جديد.',
    BanayAuthLocalizationKeys.addValidName: 'أضف اسما صحيحا للمتابعة.',
    BanayAuthLocalizationKeys.almostThere: 'اقتربنا!',
    BanayAuthLocalizationKeys.addNamePicture: 'أضف اسمك وصورة الملف الشخصي',
    BanayAuthLocalizationKeys.yourName: 'اسمك',
    BanayAuthLocalizationKeys.connecting: 'جار الاتصال...',
  },
};
