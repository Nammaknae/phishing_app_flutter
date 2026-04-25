# -*- coding: utf-8 -*-
"""
train.csv (컬럼: ID, URL, label) 기반 악성/정상 이진 분류 — 단일 XGBoost 모델만 학습합니다.
대용량 파일은 한 번에 읽지 않고 pandas chunksize로만 스트리밍합니다.
"""

import warnings
import math
import re
import urllib.parse
from collections import Counter

import joblib
import numpy as np
import pandas as pd
import tldextract
from category_encoders import BinaryEncoder
from sklearn.metrics import classification_report, confusion_matrix, roc_auc_score
from sklearn.model_selection import KFold, train_test_split
from sklearn.preprocessing import StandardScaler
from xgboost import XGBClassifier



warnings.filterwarnings("ignore", category=DeprecationWarning)

# =====================================================================
# 설정
# =====================================================================

INPUT_CSV = "train.csv"  # 컬럼: ID, URL, label (약 6,995,056행)
CHUNK_SIZE = 200_000  # 메모리에 맞게 조절
TOTAL_ROWS_EXPECTED = 6_995_056

# Train : Validation : Test = 8 : 1 : 1
TEST_SIZE_VAL_AND_TEST = 0.2  # Val+Test 합계 20%
TEST_SIZE_WITHIN_TEMP = 0.5  # 그중 절반씩 → Val 10%, Test 10%

# 타깃 인코딩용 K-Fold (학습 데이터 내부에서만 통계를 만들어 OOF로 붙임 → 리키지 완화)
KFOLD_TE_SPLITS = 5
RANDOM_STATE = 42

# 카테고리형 문자열 피처 (BinaryEncoder 대상)
CAT_COLS = ["url_path", "url_tld", "url_sld", "url_subdomain"]

MODEL_OUT = "xgb_final_v2.json"
ARTIFACTS_OUT = "xgb_train_artifacts_v2.joblib"  # 스케일러, 인코더, TE 맵 등 추론 시 재사용

# 전체 데이터 대신 일부만 쓰는 빠른 테스트용 (운영 학습 시 False 권장)
USE_SAMPLE = False
SAMPLE_N = 700_000


# =====================================================================
# URL 전처리 및 수치 피처 (기존 프로젝트의 extract_features 그대로 유지)
# =====================================================================


def normalize_url(url):
    """앞뒤 공백 제거, 디팡 복구, 스킴 보정."""
    url = str(url).strip()
    url = url.replace("[.]", ".")
    if not url.startswith(("http://", "https://")):
        url = "http://" + url
    return url


def get_registered_domain(url):
    """등록 도메인(예: naver.com) — 추론 시 규칙 보정용."""
    try:
        ext = tldextract.extract(url)
        return ext.top_domain_under_public_suffix
    except Exception:
        return ""


def entropy(s):
    if not s:
        return 0
    freq = Counter(s)
    return -sum((c / len(s)) * math.log2(c / len(s)) for c in freq.values())


def extract_features(url):
    """URL → 기존에 정의된 30개 수치 피처만 반환 (추가 파생 금지)."""
    try:
        url = normalize_url(url)
        parsed = urllib.parse.urlparse(url)
        ext = tldextract.extract(url)

        registered_domain = ext.top_domain_under_public_suffix
        subdomain = ext.subdomain
        full_domain = parsed.netloc
        path = parsed.path

        trusted_registered = [
            "google.com",
            "youtube.com",
            "naver.com",
            "kakao.com",
            "daum.net",
            "samsung.com",
            "microsoft.com",
            "apple.com",
            "facebook.com",
            "instagram.com",
            "twitter.com",
            "github.com",
            "wikipedia.org",
            "netflix.com",
            "amazon.com",
            "linkedin.com",
        ]

        is_trusted = 1 if registered_domain in trusted_registered else 0
        spoofing = (
            1
            if any(
                td.split(".")[0] in subdomain for td in trusted_registered
            )
            else 0
        )

        features = {
            "url_length": len(url),
            "domain_length": len(full_domain),
            "registered_domain_length": len(registered_domain),
            "path_length": len(path),
            "num_dots": url.count("."),
            "num_hyphens": url.count("-"),
            "num_underscores": url.count("_"),
            "num_slashes": url.count("/"),
            "num_at": url.count("@"),
            "num_question": url.count("?"),
            "num_equals": url.count("="),
            "num_ampersand": url.count("&"),
            "num_percent": url.count("%"),
            "has_https": 1 if parsed.scheme == "https" else 0,
            "has_ip": 1 if re.match(r"\d+\.\d+\.\d+\.\d+", full_domain) else 0,
            "num_subdomains": len(subdomain.split(".")) if subdomain else 0,
            "has_port": 1 if ":" in full_domain else 0,
            "has_suspicious_keyword": 1
            if any(
                kw in url.lower()
                for kw in [
                    "login",
                    "secure",
                    "account",
                    "update",
                    "bank",
                    "verify",
                    "password",
                    "confirm",
                    "signin",
                    "free",
                    "lucky",
                    "prize",
                    "win",
                    "click",
                    "urgent",
                ]
            )
            else 0,
            "is_shortened": 1
            if registered_domain
            in ["bit.ly", "tinyurl.com", "goo.gl", "t.co", "short.io"]
            else 0,
            "digit_ratio": sum(c.isdigit() for c in url) / len(url) if url else 0,
            "is_trusted_domain": is_trusted,
            "is_spoofing": spoofing,
            "domain_has_digit": 1 if re.search(r"\d", registered_domain) else 0,
            "domain_has_hyphen": 1 if "-" in registered_domain else 0,
            "tld_suspicious": 1
            if any(
                registered_domain.endswith(tld)
                for tld in [
                    ".click",
                    ".xyz",
                    ".top",
                    ".pw",
                    ".tk",
                    ".ml",
                    ".ga",
                    ".cf",
                    ".gq",
                ]
            )
            else 0,
            "punycode": 1 if "xn--" in full_domain else 0,
            "path_depth": path.count("/"),
            "query_length": len(parsed.query),
            "num_params": len(parsed.query.split("&")) if parsed.query else 0,
            "subdomain_is_numeric": 1 if subdomain.replace(".", "").isdigit() else 0,
            "domain_entropy": round(entropy(registered_domain), 4),
        }
        return features
    except Exception:
        return None


def parse_url_components(url):
    """
    URL 구조 분해 — BinaryEncoder·타깃 인코딩 그룹 키에 쓰는 문자열만 반환.
    (데이터셋 원본 컬럼 외 추가 파생 이름을 만들지 않고, 경로/도메인 구성요소만 분리)
    """
    try:
        u = normalize_url(url)
        parsed = urllib.parse.urlparse(u)
        netloc = parsed.netloc
        domain_parts = netloc.split(".") if netloc else []
        return {
            "url_path": parsed.path if parsed.path else "",
            "url_tld": domain_parts[-1] if domain_parts else "",
            "url_sld": domain_parts[-2] if len(domain_parts) > 1 else "",
            "url_subdomain": ".".join(domain_parts[:-2]) if len(domain_parts) > 2 else "",
        }
    except Exception:
        return {
            "url_path": "",
            "url_tld": "",
            "url_sld": "",
            "url_subdomain": "",
        }


def feature_vector_or_zero(url):
    """extract_features 실패 시 30차원 0 벡터로 맞춤."""
    feat = extract_features(url)
    if feat is None:
        return {k: 0.0 for k in NUMERIC_FEATURE_NAMES}
    return {k: float(feat[k]) for k in NUMERIC_FEATURE_NAMES}


_sample = extract_features("http://example.com/path")
NUMERIC_FEATURE_NAMES = list(_sample.keys()) if _sample is not None else []
#if len(NUMERIC_FEATURE_NAMES) != 30:
#    raise RuntimeError("수치 피처는 30개여야 합니다.")



def main():
    # =====================================================================
    # 1단계: 라벨만 chunksize로 읽어 Train/Val/Test 인덱스 생성 (8:1:1)
    # =====================================================================
    
    print("=" * 60)
    print("[1단계] 라벨만 로드하여 Train:Validation:Test = 8:1:1 분할 인덱스 생성")
    print("=" * 60)
    
    y_parts = []
    for chunk in pd.read_csv(
        INPUT_CSV,
        usecols=["label"],
        chunksize=CHUNK_SIZE,
        dtype={"label": "int8"},
        on_bad_lines="skip",
    ):
        y_parts.append(chunk["label"].to_numpy(copy=False))
    
    y = np.concatenate(y_parts, axis=0)
    total_rows = len(y)
    print(f"전체 행 수: {total_rows:,}")
    if total_rows != TOTAL_ROWS_EXPECTED:
        print(
            f"⚠ 기대 행 수({TOTAL_ROWS_EXPECTED:,})와 다를 수 있습니다. (현재 {total_rows:,})"
        )
    
    idx = np.arange(total_rows, dtype=np.int64)
    work_idx, work_y = idx, y
    
    if USE_SAMPLE:
        print(f"⚠ USE_SAMPLE=True → stratify로 {SAMPLE_N:,}건만 사용합니다.")
        work_idx, _, work_y, _ = train_test_split(
            idx,
            y,
            train_size=min(SAMPLE_N, total_rows),
            random_state=RANDOM_STATE,
            stratify=y,
        )
    
    # 80% / 20% → 그다음 20%를 반으로 → 10% / 10%
    idx_train, idx_temp, y_train_split, y_temp = train_test_split(
        work_idx,
        work_y,
        test_size=TEST_SIZE_VAL_AND_TEST,
        random_state=RANDOM_STATE,
        stratify=work_y,
    )
    idx_val, idx_test, y_val_split, y_test_split = train_test_split(
        idx_temp,
        y_temp,
        test_size=TEST_SIZE_WITHIN_TEMP,
        random_state=RANDOM_STATE,
        stratify=y_temp,
    )
    
    train_set = set(idx_train.tolist())
    val_set = set(idx_val.tolist())
    test_set = set(idx_test.tolist())
    
    n_train = len(idx_train)
    n_val = len(idx_val)
    n_test = len(idx_test)
    print(f"Train: {n_train:,} / Validation: {n_val:,} / Test: {n_test:,}")
    
    # 학습에만 쓰는 라벨 분포 → scale_pos_weight
    pos = int((y_train_split == 1).sum())
    neg = int((y_train_split == 0).sum())
    scale_pos_weight = (neg / pos) if pos > 0 else 1.0
    print(f"Train 내 scale_pos_weight (neg/pos): {scale_pos_weight:.4f}\n")
    
    
    # =====================================================================
    # 2단계: 스트리밍으로 Train 행만 모아 타깃 인코딩용 (url_tld, url_sld, label)
    #        → 학습 데이터 내부 K-Fold OOF 통계 + 전체 Train 집계 맵
    # =====================================================================
    
    print("=" * 60)
    print("[2단계] Train 구간만 스트리밍하여 타깃 인코딩용 표 준비 (K-Fold OOF)")
    print("=" * 60)
    
    train_tld_list = []
    train_sld_list = []
    train_y_list = []
    
    row_offset = 0
    for chunk in pd.read_csv(
        INPUT_CSV,
        usecols=["URL", "label"],
        chunksize=CHUNK_SIZE,
        dtype={"label": "int8"},
        on_bad_lines="skip",
    ):
        n = len(chunk)
        if n == 0:
            continue
        urls = chunk["URL"].astype(str).to_numpy()
        labels = chunk["label"].to_numpy(copy=False)
    
        for i in range(n):
            g = row_offset + i
            if g not in train_set:
                continue
            url = urls[i]
            comp = parse_url_components(url)
            train_tld_list.append(comp["url_tld"] if comp["url_tld"] is not None else "")
            train_sld_list.append(comp["url_sld"] if comp["url_sld"] is not None else "")
            train_y_list.append(int(labels[i]))
    
        row_offset += n
        if row_offset % 1_000_000 == 0:
            print(f"  스캔 진행: {row_offset:,} / {total_rows:,} 행...")
    
    df_te_train = pd.DataFrame(
        {"url_tld": train_tld_list, "url_sld": train_sld_list, "label": train_y_list}
    )
    global_mean_train = float(df_te_train["label"].mean())
    print(f"Train 전역 라벨 평균(악성 비율): {global_mean_train:.6f}")
    
    # K-Fold OOF: 각 검증 폴드 행에는 '그 폴드가 아닌' 학습 폴드에서만 계산한 그룹 평균을 매핑
    kf_te = KFold(n_splits=KFOLD_TE_SPLITS, shuffle=True, random_state=RANDOM_STATE)
    oof_tld = np.zeros(len(df_te_train), dtype=np.float64)
    oof_sld = np.zeros(len(df_te_train), dtype=np.float64)
    
    for col, oof_arr in [("url_tld", oof_tld), ("url_sld", oof_sld)]:
        for tr_idx, va_idx in kf_te.split(df_te_train):
            tr = df_te_train.iloc[tr_idx]
            # 폴드 내부 학습 구간에서만 그룹별 악성 비율
            grp_mean = tr.groupby(col)["label"].mean()
            mapped = df_te_train.iloc[va_idx][col].map(grp_mean)
            oof_arr[va_idx] = mapped.fillna(global_mean_train).to_numpy()
    
    # Validation/Test에 쓸 맵: Train 전체에서만 추정 (Val/Test 라벨은 사용하지 않음)
    map_tld_full = df_te_train.groupby("url_tld")["label"].mean()
    map_sld_full = df_te_train.groupby("url_sld")["label"].mean()
    
    print("타깃 인코딩(OOF) 및 Train 집계 맵 계산 완료.\n")
    
    
    # =====================================================================
    # 3단계: 다시 스트리밍하여 Train/Val/Test 행렬 채움 (수치 30 + TE 2 + 범주 4)
    # =====================================================================
    
    print("=" * 60)
    print("[3단계] 전체 CSV 스트리밍 — 피처 행렬 적재 (메모리: 배열 사전 할당)")
    print("=" * 60)
    
    num_cols = len(NUMERIC_FEATURE_NAMES) + 2  # + te_tld, te_sld
    X_train_num = np.zeros((n_train, num_cols), dtype=np.float32)
    X_val_num = np.zeros((n_val, num_cols), dtype=np.float32)
    X_test_num = np.zeros((n_test, num_cols), dtype=np.float32)
    
    X_train_cat = np.empty((n_train, len(CAT_COLS)), dtype=object)
    X_val_cat = np.empty((n_val, len(CAT_COLS)), dtype=object)
    X_test_cat = np.empty((n_test, len(CAT_COLS)), dtype=object)
    
    y_train_arr = np.empty(n_train, dtype=np.int8)
    y_val_arr = np.empty(n_val, dtype=np.int8)
    y_test_arr = np.empty(n_test, dtype=np.int8)
    
    # Train OOF는 df_te_train과 동일 순서(파일 상에서 Train 행이 등장한 순서)로 적재했다고 가정
    # → 2단계에서 쌓은 순서와 3단계에서 Train에 쓰는 순서가 같아야 함
    train_te_pos = 0
    val_pos = 0
    test_pos = 0
    
    row_offset = 0
    for chunk in pd.read_csv(
        INPUT_CSV,
        usecols=["URL", "label"],
        chunksize=CHUNK_SIZE,
        dtype={"label": "int8"},
        on_bad_lines="skip",
    ):
        n = len(chunk)
        if n == 0:
            continue
        urls = chunk["URL"].astype(str).to_numpy()
        labels = chunk["label"].to_numpy(copy=False)
    
        for i in range(n):
            g = row_offset + i
            url = urls[i]
            lab = int(labels[i])
            comp = parse_url_components(url)
            num_dict = feature_vector_or_zero(url)
    
            if g in train_set:
                te_t = float(oof_tld[train_te_pos])
                te_s = float(oof_sld[train_te_pos])
                for j, name in enumerate(NUMERIC_FEATURE_NAMES):
                    X_train_num[train_te_pos, j] = num_dict[name]
                X_train_num[train_te_pos, len(NUMERIC_FEATURE_NAMES)] = te_t
                X_train_num[train_te_pos, len(NUMERIC_FEATURE_NAMES) + 1] = te_s
                for c, col in enumerate(CAT_COLS):
                    v = comp.get(col, "")
                    X_train_cat[train_te_pos, c] = v if v is not None else ""
                y_train_arr[train_te_pos] = lab
                train_te_pos += 1
    
            elif g in val_set:
                # Validation/Test: Train 전체에서만 추정한 그룹 평균으로 매핑 (라벨 누출 없음)
                kt, ks = comp["url_tld"], comp["url_sld"]
                te_t = float(map_tld_full[kt]) if kt in map_tld_full.index else global_mean_train
                te_s = float(map_sld_full[ks]) if ks in map_sld_full.index else global_mean_train
                for j, name in enumerate(NUMERIC_FEATURE_NAMES):
                    X_val_num[val_pos, j] = num_dict[name]
                X_val_num[val_pos, len(NUMERIC_FEATURE_NAMES)] = te_t
                X_val_num[val_pos, len(NUMERIC_FEATURE_NAMES) + 1] = te_s
                for c, col in enumerate(CAT_COLS):
                    v = comp.get(col, "")
                    X_val_cat[val_pos, c] = v if v is not None else ""
                y_val_arr[val_pos] = lab
                val_pos += 1
    
            elif g in test_set:
                kt, ks = comp["url_tld"], comp["url_sld"]
                te_t = float(map_tld_full[kt]) if kt in map_tld_full.index else global_mean_train
                te_s = float(map_sld_full[ks]) if ks in map_sld_full.index else global_mean_train
                for j, name in enumerate(NUMERIC_FEATURE_NAMES):
                    X_test_num[test_pos, j] = num_dict[name]
                X_test_num[test_pos, len(NUMERIC_FEATURE_NAMES)] = te_t
                X_test_num[test_pos, len(NUMERIC_FEATURE_NAMES) + 1] = te_s
                for c, col in enumerate(CAT_COLS):
                    v = comp.get(col, "")
                    X_test_cat[test_pos, c] = v if v is not None else ""
                y_test_arr[test_pos] = lab
                test_pos += 1
    
        row_offset += n
        if row_offset % 1_000_000 == 0:
            print(f"  피처 적재: {row_offset:,} / {total_rows:,} 행...")
    
    if train_te_pos != n_train or val_pos != n_val or test_pos != n_test:
        raise RuntimeError(
            f"행 수 불일치: train {train_te_pos}!={n_train}, val {val_pos}!={n_val}, test {test_pos}!={n_test}"
        )
    
    numeric_feature_names_all = NUMERIC_FEATURE_NAMES + ["te_tld", "te_sld"]
    print(f"수치 피처 열 이름(스케일 대상): {len(numeric_feature_names_all)}개\n")
    
    
    # =====================================================================
    # 4단계: BinaryEncoder(범주) + StandardScaler(수치) — 학습 데이터에만 fit
    # =====================================================================
    
    print("=" * 60)
    print("[4단계] BinaryEncoder + StandardScaler (Train에만 fit)")
    print("=" * 60)
    
    X_train_cat_df = pd.DataFrame(X_train_cat, columns=CAT_COLS)
    X_val_cat_df = pd.DataFrame(X_val_cat, columns=CAT_COLS)
    X_test_cat_df = pd.DataFrame(X_test_cat, columns=CAT_COLS)
    
    for d in (X_train_cat_df, X_val_cat_df, X_test_cat_df):
        d.fillna("", inplace=True)
    
    binary_encoder = BinaryEncoder(cols=CAT_COLS, handle_unknown="value")
    X_train_enc = binary_encoder.fit_transform(X_train_cat_df)
    X_val_enc = binary_encoder.transform(X_val_cat_df)
    X_test_enc = binary_encoder.transform(X_test_cat_df)
    
    scaler = StandardScaler()
    X_train_num_scaled = scaler.fit_transform(X_train_num)
    X_val_num_scaled = scaler.transform(X_val_num)
    X_test_num_scaled = scaler.transform(X_test_num)
    
    X_train_final = np.hstack([X_train_num_scaled, X_train_enc.to_numpy(dtype=np.float32)])
    X_val_final = np.hstack([X_val_num_scaled, X_val_enc.to_numpy(dtype=np.float32)])
    X_test_final = np.hstack([X_test_num_scaled, X_test_enc.to_numpy(dtype=np.float32)])
    
    print(
        f"최종 설계행렬 크기: Train {X_train_final.shape}, Val {X_val_final.shape}, Test {X_test_final.shape}\n"
    )
    
    
    # =====================================================================
    # 5단계: 단일 XGBoostClassifier 학습 및 평가
    # =====================================================================
    
    print("=" * 60)
    print("[5단계] 단일 XGBoostClassifier 학습 (eval_set=Validation)")
    print("=" * 60)
    
    model = XGBClassifier(
        n_estimators=300,
        max_depth=6,
        learning_rate=0.1,
        objective="binary:logistic",
        eval_metric="logloss",
        random_state=RANDOM_STATE,
        n_jobs=-1,
        scale_pos_weight=scale_pos_weight,
        tree_method="hist",
    )
    
    model.fit(
        X_train_final,
        y_train_arr,
        eval_set=[(X_val_final, y_val_arr)],
        verbose=50,
    )
    
    # Validation
    val_proba = model.predict_proba(X_val_final)[:, 1]
    val_pred = (val_proba >= 0.5).astype(int)
    print("\n=== Validation 분류 리포트 ===")
    print(classification_report(y_val_arr, val_pred, target_names=["정상(0)", "악성(1)"]))
    print("Validation ROC-AUC:", roc_auc_score(y_val_arr, val_proba))
    
    # Test (최종 1회)
    test_proba = model.predict_proba(X_test_final)[:, 1]
    test_pred = (test_proba >= 0.5).astype(int)
    print("\n=== Test 분류 리포트 (최종 평가) ===")
    print(classification_report(y_test_arr, test_pred, target_names=["정상(0)", "악성(1)"]))
    print("Test ROC-AUC:", roc_auc_score(y_test_arr, test_proba))
    print("\n=== Test 혼동 행렬 ===")
    cm = confusion_matrix(y_test_arr, test_pred)
    print(cm)
    if cm.shape == (2, 2):
        print(
            f"\n미탐(악성→정상): {cm[1][0]} ({cm[1][0]/cm[1].sum()*100:.2f}% of 악성)"
        )
        print(
            f"오탐(정상→악성): {cm[0][1]} ({cm[0][1]/cm[0].sum()*100:.2f}% of 정상)"
        )
    
    model.save_model(MODEL_OUT)
    print(f"\n모델 저장: {MODEL_OUT}")
    
    artifacts = {
        "binary_encoder": binary_encoder,
        "scaler": scaler,
        "numeric_feature_names": NUMERIC_FEATURE_NAMES,
        "numeric_feature_names_with_te": numeric_feature_names_all,
        "cat_cols": CAT_COLS,
        "map_tld_full": map_tld_full,
        "map_sld_full": map_sld_full,
        "global_mean_train": global_mean_train,
        "scale_pos_weight": scale_pos_weight,
    }
    joblib.dump(artifacts, ARTIFACTS_OUT)
    print(f"전처리/TE 맵 저장: {ARTIFACTS_OUT}")
    print("\n학습 파이프라인 종료.")


if __name__ == "__main__":
    main()
