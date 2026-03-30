#' Shared Parameter Documentation
#'
#' @name shared_params
#'
#' @param protocol Character. Protocol string. Defaults to "sftp".
#' @param hostname Character. Server URL or IP. Defaults to "localhost".
#' @param path Character. Sub-path on server.
#' @param port Character. Port number. Defaults to "22".
#' @param user Character. SFTP account name.
#' @param password Character. SFTP password.
#' @param timeout Integer. Connection timeout.
#' @param ... Additional arguments passed to \code{curl::handle_setopt()}.
#' @param .verbose Logical. Defaults to \code{TRUE}.
#'   Prints helpful messages.
#'
#' @param sftp_conn An \code{SFTPConn} object containing connection details and
#'   authentication. Created by \code{\link{sftp_connect}}.
#'
#' @param remote_url Character. The full URL or path of the file or directory to
#'   be operated on.
#'
#' @param .recursive Logical. Defaults to \code{FALSE}. If \code{TRUE},
#'   will recursively perform the SFTP operation:
#'   \itemize{
#'     \item \code{sftp_delete()}: deletes the directory and everything within.
#'     \item \code{sftp_list()}: lists all the directories and files.
#'     \item \code{sftp_mkdir()}: creates all the missing parent directories.
#'     \item \code{sftp_rename()}: see \code{sftp_mkdir()}.
#'   }
#'
#' @param .create_dir Logical. Defaults to \code{FALSE}. If \code{TRUE},
#'   creates the necessary parent directories if needed.
#'
#' @keywords internal
#'
NULL