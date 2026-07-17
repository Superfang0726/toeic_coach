/// Drives which view `ChatUi` renders.
///
/// The intended progression is `generatingQuestion` → `displayingQuestion`
/// → `generatingReview` → `displayingReview`, with
/// `failToGenerateQuestion` / `failToGenerateReview` as branches off the
/// two generating states when a Gemini call errors out.
enum ChatState {
  waitingUserGenerateQuestion,
  generatingQuestion,
  failToGenerateQuestion,
  displayingQuestion,
  generatingReview,
  failToGenerateReview,
  displayingReview,
}
