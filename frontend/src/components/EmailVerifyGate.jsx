import { useAuth } from "../context/AuthContext";
import EmailVerifyForm from "./EmailVerifyForm";

export default function EmailVerifyGate() {
  const { isLoggedIn, isEmailVerified, user, refreshUser, verifyModalOpen, openVerifyModal, closeVerifyModal } =
    useAuth();

  if (!isLoggedIn || isEmailVerified || !user) return null;

  return (
    <>
      <div className="alert alert-warning rounded-none justify-center text-sm">
        <span>
          이메일 인증이 필요합니다.{" "}
          <button className="link font-semibold" onClick={openVerifyModal}>
            지금 인증하기
          </button>
        </span>
      </div>

      {verifyModalOpen && (
        <div className="modal modal-open">
          <div className="modal-box max-w-sm relative">
            <button
              className="btn btn-sm btn-circle btn-ghost absolute right-2 top-2"
              onClick={closeVerifyModal}
              aria-label="닫기"
            >
              ✕
            </button>
            <h3 className="text-lg font-bold text-center mb-3">이메일 인증</h3>
            <EmailVerifyForm
              email={user.email}
              requireSendFirst
              onVerified={() => {
                refreshUser();
                closeVerifyModal();
              }}
            />
          </div>
        </div>
      )}
    </>
  );
}
