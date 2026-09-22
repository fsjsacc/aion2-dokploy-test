import { D as __toESM, n as require_jsx_runtime, x as require_react } from "../index.js";
import { n as trackEvent } from "./analytics-D_3EN7IN.js";
//#region app/_components/codes/CodesPage.module.css
var import_react = /* @__PURE__ */ __toESM(require_react(), 1);
var CodesPage_module_default = {
	page: "_page_bldfz_1",
	shell: "_shell_bldfz_19",
	hero: "_hero_bldfz_27",
	breadcrumbs: "_breadcrumbs_bldfz_37",
	heroGrid: "_heroGrid_bldfz_73",
	sectionHeading: "_sectionHeading_bldfz_75",
	eyebrow: "_eyebrow_bldfz_89",
	heroAside: "_heroAside_bldfz_125",
	jumpLinks: "_jumpLinks_bldfz_141",
	stats: "_stats_bldfz_179",
	activeSection: "_activeSection_bldfz_247",
	historySection: "_historySection_bldfz_249",
	guideSection: "_guideSection_bldfz_251",
	activeGrid: "_activeGrid_bldfz_305",
	historyGrid: "_historyGrid_bldfz_315",
	codeCard: "_codeCard_bldfz_327",
	featuredCard: "_featuredCard_bldfz_349",
	historyCard: "_historyCard_bldfz_361",
	cardHeader: "_cardHeader_bldfz_369",
	cardTitle: "_cardTitle_bldfz_393",
	codeValue: "_codeValue_bldfz_407",
	statusBadge: "_statusBadge_bldfz_449",
	copyControl: "_copyControl_bldfz_515",
	loadingStatus: "_loadingStatus_bldfz_525",
	loadingSlot: "_loadingSlot_bldfz_545",
	revealHint: "_revealHint_bldfz_559",
	loadingText: "_loadingText_bldfz_573",
	"code-spinner": "_code-spinner_bldfz_1",
	loadingTrack: "_loadingTrack_bldfz_605",
	"code-reveal-progress": "_code-reveal-progress_bldfz_1",
	copyButton: "_copyButton_bldfz_645",
	officialButton: "_officialButton_bldfz_647",
	cancelButton: "_cancelButton_bldfz_705",
	confirmButton: "_confirmButton_bldfz_707",
	sourceLinks: "_sourceLinks_bldfz_713",
	relatedLinks: "_relatedLinks_bldfz_715",
	confirmDialog: "_confirmDialog_bldfz_725",
	"confirm-dialog-in": "_confirm-dialog-in_bldfz_1",
	confirmDialogInner: "_confirmDialogInner_bldfz_785",
	confirmIcon: "_confirmIcon_bldfz_793",
	confirmActions: "_confirmActions_bldfz_849",
	factList: "_factList_bldfz_975",
	periodFact: "_periodFact_bldfz_1047",
	rewards: "_rewards_bldfz_1067",
	guideCard: "_guideCard_bldfz_1077",
	caution: "_caution_bldfz_1079",
	cardFooter: "_cardFooter_bldfz_1153",
	guideGrid: "_guideGrid_bldfz_1207",
	guideNumber: "_guideNumber_bldfz_1235",
	srOnly: "_srOnly_bldfz_1499"
};
//#endregion
//#region app/_components/codes/CopyCodeButton.tsx
var import_jsx_runtime = require_jsx_runtime();
var REVEAL_DELAY_MS = 4500;
async function writeToClipboard(value) {
	if (navigator.clipboard && window.isSecureContext) {
		await navigator.clipboard.writeText(value);
		return;
	}
	const textarea = document.createElement("textarea");
	textarea.value = value;
	textarea.setAttribute("readonly", "");
	textarea.style.position = "fixed";
	textarea.style.opacity = "0";
	document.body.appendChild(textarea);
	textarea.select();
	const copied = document.execCommand("copy");
	textarea.remove();
	if (!copied) throw new Error("Clipboard copy was rejected");
}
function CodeRevealControl({ code, codeId, codeStatus, controlId, locale, showCodeLabel, loadingCodeLabel, copyLabel, copyingLabel, copiedLabel, failedLabel, confirmCopyTitle, confirmCopyMessage, confirmCopyLabel, cancelLabel }) {
	const [revealState, setRevealState] = (0, import_react.useState)("hidden");
	const [copyState, setCopyState] = (0, import_react.useState)("idle");
	const revealTimer = (0, import_react.useRef)(null);
	const resetTimer = (0, import_react.useRef)(null);
	const copyInFlight = (0, import_react.useRef)(false);
	const actionButtonRef = (0, import_react.useRef)(null);
	const dialogRef = (0, import_react.useRef)(null);
	const confirmButtonRef = (0, import_react.useRef)(null);
	const analyticsPayload = {
		code_id: codeId,
		code_status: codeStatus,
		locale,
		surface: "content-detail",
		target_kind: "tool",
		target_key: "code-center",
		tool_name: "code-center"
	};
	(0, import_react.useEffect)(() => () => {
		if (revealTimer.current !== null) window.clearTimeout(revealTimer.current);
		if (resetTimer.current !== null) window.clearTimeout(resetTimer.current);
	}, []);
	function revealCode() {
		if (revealState !== "hidden") return;
		trackEvent("code_reveal_start", analyticsPayload);
		setRevealState("loading");
		revealTimer.current = window.setTimeout(() => {
			setRevealState("revealed");
			revealTimer.current = null;
			trackEvent("code_reveal_complete", {
				...analyticsPayload,
				reveal_delay_ms: REVEAL_DELAY_MS
			});
		}, REVEAL_DELAY_MS);
	}
	function openCopyConfirmation() {
		const dialog = dialogRef.current;
		if (!dialog || dialog.open) return;
		dialog.showModal();
		trackEvent("code_copy_confirm_open", analyticsPayload);
		window.requestAnimationFrame(() => confirmButtonRef.current?.focus());
	}
	function closeCopyConfirmation() {
		if (dialogRef.current?.open) dialogRef.current.close();
		window.requestAnimationFrame(() => actionButtonRef.current?.focus());
	}
	function handleDialogCancel(event) {
		if (copyInFlight.current) {
			event.preventDefault();
			return;
		}
		closeCopyConfirmation();
	}
	async function confirmCopy() {
		if (copyInFlight.current) return;
		copyInFlight.current = true;
		setCopyState("copying");
		const copyMethod = navigator.clipboard && window.isSecureContext ? "async_clipboard" : "exec_command";
		try {
			await writeToClipboard(code);
			setCopyState("copied");
			trackEvent("code_copy_success", {
				...analyticsPayload,
				copy_method: copyMethod
			});
		} catch {
			setCopyState("failed");
			trackEvent("code_copy_failure", {
				...analyticsPayload,
				copy_method: copyMethod,
				failure_reason: "clipboard_rejected"
			});
		} finally {
			copyInFlight.current = false;
		}
		closeCopyConfirmation();
		if (resetTimer.current !== null) window.clearTimeout(resetTimer.current);
		resetTimer.current = window.setTimeout(() => setCopyState("idle"), 2600);
	}
	const copyButtonLabel = copyState === "copying" ? copyingLabel : copyState === "copied" ? copiedLabel : copyState === "failed" ? failedLabel : copyLabel;
	const actionLabel = revealState === "hidden" ? showCodeLabel : revealState === "loading" ? loadingCodeLabel : copyButtonLabel;
	const codeIsRevealed = revealState === "revealed";
	return /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
		className: CodesPage_module_default.copyControl,
		"data-code-reveal-control": true,
		"data-reveal-delay-ms": REVEAL_DELAY_MS,
		"data-state": revealState,
		children: [
			/* @__PURE__ */ (0, import_jsx_runtime.jsx)("code", {
				"aria-label": codeIsRevealed ? code : showCodeLabel,
				className: CodesPage_module_default.codeValue,
				"data-hidden": codeIsRevealed ? "false" : "true",
				id: `${controlId}-value`,
				children: codeIsRevealed ? code : "••••••••••••"
			}),
			/* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
				className: CodesPage_module_default.loadingSlot,
				children: revealState === "loading" ? /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
					"aria-live": "polite",
					className: CodesPage_module_default.loadingStatus,
					role: "status",
					children: [/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("span", {
						className: CodesPage_module_default.loadingText,
						children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("i", { "aria-hidden": "true" }), loadingCodeLabel]
					}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
						"aria-hidden": "true",
						className: CodesPage_module_default.loadingTrack,
						children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {})
					})]
				}) : revealState === "revealed" ? /* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
					className: CodesPage_module_default.revealHint,
					children: confirmCopyMessage
				}) : null
			}),
			/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("button", {
				"aria-controls": `${controlId}-value`,
				"aria-expanded": codeIsRevealed ? void 0 : false,
				className: CodesPage_module_default.copyButton,
				"data-code-reveal": revealState === "hidden" ? "trigger" : void 0,
				"data-state": revealState === "revealed" ? copyState : revealState,
				disabled: revealState === "loading",
				onClick: codeIsRevealed ? openCopyConfirmation : revealCode,
				ref: actionButtonRef,
				type: "button",
				children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
					"aria-hidden": "true",
					children: revealState === "loading" ? "◌" : copyState === "copied" ? "✓" : codeIsRevealed ? "⧉" : "◉"
				}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", { children: actionLabel })]
			}),
			/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
				"aria-live": "polite",
				className: CodesPage_module_default.srOnly,
				role: "status",
				children: copyState === "idle" ? "" : copyButtonLabel
			}),
			/* @__PURE__ */ (0, import_jsx_runtime.jsx)("dialog", {
				"aria-describedby": `${controlId}-confirm-message`,
				"aria-labelledby": `${controlId}-confirm-title`,
				"aria-modal": "true",
				className: CodesPage_module_default.confirmDialog,
				"data-code-confirmation": true,
				onCancel: handleDialogCancel,
				onClick: (event) => {
					if (event.currentTarget === event.target && !copyInFlight.current) closeCopyConfirmation();
				},
				ref: dialogRef,
				role: "dialog",
				children: /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
					className: CodesPage_module_default.confirmDialogInner,
					children: [
						/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
							"aria-hidden": "true",
							className: CodesPage_module_default.confirmIcon,
							children: "⧉"
						}),
						/* @__PURE__ */ (0, import_jsx_runtime.jsx)("h3", {
							id: `${controlId}-confirm-title`,
							children: confirmCopyTitle
						}),
						/* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
							id: `${controlId}-confirm-message`,
							children: confirmCopyMessage
						}),
						/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
							className: CodesPage_module_default.confirmActions,
							children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("button", {
								className: CodesPage_module_default.cancelButton,
								disabled: copyState === "copying",
								onClick: closeCopyConfirmation,
								type: "button",
								children: cancelLabel
							}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("button", {
								className: CodesPage_module_default.confirmButton,
								"aria-busy": copyState === "copying",
								disabled: copyState === "copying",
								onClick: confirmCopy,
								ref: confirmButtonRef,
								type: "button",
								children: copyState === "copying" ? copyingLabel : confirmCopyLabel
							})]
						})
					]
				})
			})
		]
	});
}
//#endregion
export { CodeRevealControl };
