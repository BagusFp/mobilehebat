import 'package:flutter/foundation.dart';
import 'quiz_model.dart';

class QuizProvider extends ChangeNotifier {
  int _currentQuestionIndex = 0;
  int? _selectedOptionIndex;
  bool _isAnswered = false;
  int _userScore = 850; // Skor awal Jagawana dari PRD/Stitch
  int _sessionEarnedPoints = 0;
  int _sessionCorrectCount = 0;

  final List<QuizQuestionModel> _questions = const [
    QuizQuestionModel(
      id: 1,
      category: 'Geologi & Wisata Edukasi',
      question:
          'Bongkahan batu vulkanik besar dengan kontur menyerupai wajah manusia yang terlempar dari erupsi Merapi ini dinamakan...?',
      imageUrl:
          'https://lh3.googleusercontent.com/aida-public/AB6AXuCR4QTca6FjYWdM84LRoA24ikLOIoICntmsW6kZ4w862lL9v79LUZqDJi2O18nyJQB49xTYTaymv-oNt38cv94lnS0zpF1cl6Pvs46iX2RTrYxHUP2d5Wb7x2g6fQYhSmtvfPw0pNHa3y6sGzl44lmP9g1CPL5WhsxUlt-TAOB_tw09s4mRAwRNmsqUmrDPn5fR4zomVpeiI0Rd0G9iL5OE8TjKqfFy_w8hFmq2UDiIdqE3nYZuui0',
      locationTag: 'Kawasan Dusun Jambu, Cangkringan',
      options: [
        'Batu Gajah Kaliadem',
        'Batu Alien Cangkringan',
        'Batu Petilasan Mbah Maridjan',
        'Batu Menhir Kalikuning',
      ],
      correctIndex: 1,
      explanation:
          'Batu Alien terlempar dari erupsi dahsyat tahun 2010 dan terletak di Dusun Jambu, Kepuharjo. Fenomena pareidolia membuat bongkahan piroklastik ini tampak jelas memiliki hidung, mata, dan lekuk wajah.',
    ),
    QuizQuestionModel(
      id: 2,
      category: 'Mitigasi Bencana & Keselamatan',
      question:
          'Pada status Merapi Level II (Waspada), berapa radius jarak aman minimum yang direkomendasikan BPPTKG untuk aktivitas pariwisata dari puncak kawah?',
      imageUrl:
          'https://lh3.googleusercontent.com/aida-public/AB6AXuD__JTBQcN2VsrNHKnYZ3FxiZdpsu2-fckBgW-YFTPB2_IwRsWRTY0ZzPK3EY0nOTR9Jaut-9xVIAY7bJ0r5GeR5Bp6WKDYOBF8nqbDwSw2iRpvqT-lu6DRI-DJ3fgMNSdprlLU4CPEld1KWrAocN1GBaG6J3iyYnlEw9_cvpKjcZAeSyY_sWN4k8zIzEvVJH4PvHj12yNDoQ4qetdwZJVqvmwcvyYcl_Kf_2lp-GWVsts1KsPJGgk',
      locationTag: 'Puncak Kawah Gunung Merapi',
      options: [
        'Radius 1 km dari puncak',
        'Radius di luar 3 km dari puncak kawah',
        'Radius 10 km dari lereng selatan',
        'Tidak ada batasan selama siang hari',
      ],
      correctIndex: 1,
      explanation:
          'Pada status Waspada Level II, sektor wisata seperti Bunker Kaliadem (4.2 km) dan Plunyon (5 km) aman dikunjungi karena berada di luar radius bahaya KRB III 3 km dari kawah aktif.',
    ),
    QuizQuestionModel(
      id: 3,
      category: 'Sejarah & Konservasi Merapi',
      question:
          'Struktur perlindungan bawah tanah di lereng Kaliadem yang dibangun untuk tempat evakuasi darurat dari awan panas Merapi disebut...?',
      imageUrl:
          'https://lh3.googleusercontent.com/aida-public/AB6AXuD__JTBQcN2VsrNHKnYZ3FxiZdpsu2-fckBgW-YFTPB2_IwRsWRTY0ZzPK3EY0nOTR9Jaut-9xVIAY7bJ0r5GeR5Bp6WKDYOBF8nqbDwSw2iRpvqT-lu6DRI-DJ3fgMNSdprlLU4CPEld1KWrAocN1GBaG6J3iyYnlEw9_cvpKjcZAeSyY_sWN4k8zIzEvVJH4PvHj12yNDoQ4qetdwZJVqvmwcvyYcl_Kf_2lp-GWVsts1KsPJGgk',
      locationTag: 'Desa Kepuharjo, Sleman',
      options: [
        'Terowongan Nglipar',
        'Bunker Kaliadem',
        'Gua Jepang Kaliurang',
        'Shelter Pengungsian Maguwo',
      ],
      correctIndex: 1,
      explanation:
          'Bunker Kaliadem dibangun tahun 2001 dengan pintu baja tebal dan ventilasi khusus sebagai tempat perlindungan darurat relawan dan tim pantau saat terjadi guguran awan panas tiba-tiba.',
    ),
    QuizQuestionModel(
      id: 4,
      category: 'Ekosistem & Hutan Pinus',
      question:
          'Destinasi wisata alam di lereng selatan yang terkenal dengan jembatan gantung peninggalan era kolonial dan panorama hutan pinus asri adalah...?',
      imageUrl:
          'https://lh3.googleusercontent.com/aida-public/AB6AXuAxs1ZRG_JYRdao6KZbp90pfUuYWEqGyJM8OkwB-Q8IkvSBkwdC4kBI3UifSPp-UqlaZthO9AwYXZJZK7BPO9Iq0rmgobdodQcqlWVKYAe0AV9KB3_9vSXsxtl0SXqNh0D9KlZycgTCSMvRq5NZfNwZlZhiZmgI-f50c8DVNrMh3xlYUOd5cGl9D4ytvL6Grc_sQNXINF1ETRO7VAgPTwTKgo_OZqiM5aVfuHmbXl063UP4YHwxURc',
      locationTag: 'Um測lharjo, Cangkringan',
      options: [
        'Taman Nasional Tlogo Putri',
        'Plunyon Kalikuning',
        'Gondoarum Viewpoint',
        'Bukit Klangon Glamping',
      ],
      correctIndex: 1,
      explanation:
          'Plunyon Kalikuning menyajikan jembatan saluran air kuno yang melintasi lembah Kalikuning dengan latar tegakan pohon pinus dan lereng Merapi.',
    ),
    QuizQuestionModel(
      id: 5,
      category: 'Morfologi & Arah Bahaya Erupsi',
      question:
          'Sungai utama di sisi selatan-tenggara Merapi yang menjadi alur luncuran material lahar dan awan panas terpanjang pada erupsi besar 2010 adalah...?',
      imageUrl:
          'https://lh3.googleusercontent.com/aida-public/AB6AXuDnewMUxraaoMgsDZ14E3ySpfnSJs9bnzZp8wc3RA9G4TaYAPVbF-yXiIze2KnRF2wueiIbn18uKgQ8S9drhcNBbCqUqQZeHd0NWHAHkp5uK372tlpHMyrhEX-myc5cT-_TXk_FxMNaOtVDhqATfeK6GbLPdxMUL0VBA8hRQphwhCUZG2ag3fIQTa0SEwlEtabIDrS3DnLItFzeyxZbRQREoQr8RWceeWsfClw-XeroHn2zTERL4Rw',
      locationTag: 'Hulu Sungai Merapi Selatan',
      options: [
        'Kali Gendol',
        'Kali Progo',
        'Kali Code Bawah',
        'Kali Oyo Gunungkidul',
      ],
      correctIndex: 0,
      explanation:
          'Kali Gendol merupakan lembah sungai utama di sektor selatan-tenggara yang dialiri endapan piroklastik hingga belasan kilometer saat kubah lava Merapi runtuh.',
    ),
  ];

  final List<QuizLeaderboardItem> _leaderboard = const [
    QuizLeaderboardItem(name: 'Aditya Pratama', points: 1250, rankTitle: 'Jagawana Utama', avatarLetter: 'A'),
    QuizLeaderboardItem(name: 'Bima Sakti (Kamu)', points: 850, rankTitle: 'Jagawana Tingkat 3', avatarLetter: 'B', isCurrentUser: true),
    QuizLeaderboardItem(name: 'Citra Wulandari', points: 800, rankTitle: 'Jagawana Madya', avatarLetter: 'C'),
    QuizLeaderboardItem(name: 'Dimas Setiawan', points: 750, rankTitle: 'Jagawana Muda', avatarLetter: 'D'),
    QuizLeaderboardItem(name: 'Eka Lestari', points: 600, rankTitle: 'Jagawana Pemula', avatarLetter: 'E'),
  ];

  // Getters
  int get currentQuestionIndex => _currentQuestionIndex;
  int? get selectedOptionIndex => _selectedOptionIndex;
  bool get isAnswered => _isAnswered;
  int get userScore => _userScore;
  int get sessionEarnedPoints => _sessionEarnedPoints;
  int get sessionCorrectCount => _sessionCorrectCount;
  int get totalQuestions => _questions.length;
  List<QuizQuestionModel> get questions => _questions;
  List<QuizLeaderboardItem> get leaderboard => _leaderboard;

  QuizQuestionModel get currentQuestion => _questions[_currentQuestionIndex];

  bool get isCurrentAnswerCorrect {
    if (!_isAnswered || _selectedOptionIndex == null) return false;
    return _selectedOptionIndex == currentQuestion.correctIndex;
  }

  bool get isQuizFinished => _currentQuestionIndex >= _questions.length - 1 && _isAnswered;

  double get progressFraction => (_currentQuestionIndex + 1) / _questions.length;
  int get progressPercent => ((_currentQuestionIndex + 1) / _questions.length * 100).toInt();

  String get activeRankTitle {
    if (_userScore >= 1200) return 'Jagawana Utama';
    if (_userScore >= 800) return 'Jagawana Merapi Tingkat 3';
    if (_userScore >= 500) return 'Jagawana Madya';
    return 'Jagawana Pemula';
  }

  // Actions
  void answerQuestion(int optionIndex) {
    if (_isAnswered) return;

    _selectedOptionIndex = optionIndex;
    _isAnswered = true;

    if (optionIndex == currentQuestion.correctIndex) {
      _sessionCorrectCount++;
      _sessionEarnedPoints += 50;
      _userScore += 50;
    }

    notifyListeners();
  }

  void nextQuestion() {
    if (_currentQuestionIndex < _questions.length - 1) {
      _currentQuestionIndex++;
      _selectedOptionIndex = null;
      _isAnswered = false;
      notifyListeners();
    }
  }

  void resetQuiz() {
    _currentQuestionIndex = 0;
    _selectedOptionIndex = null;
    _isAnswered = false;
    _sessionEarnedPoints = 0;
    _sessionCorrectCount = 0;
    notifyListeners();
  }
}
